% --- Step 1: Input Data Profiles (24 Hours) ---
hours = 1:24;

% 1. Load Demand Profile (kW) - peaks in the evening
P_load = [30, 28, 25, 25, 27, 35, 50, 65, 70, 75, 70, 65, 60, 65, 70, 85, 95, 100, 90, 80, 70, 55, 45, 35];

% 2. Solar Generation Profile (kW) - peaks at noon
P_solar = [0, 0, 0, 0, 0, 5, 20, 45, 65, 80, 90, 95, 90, 80, 60, 35, 15, 2, 0, 0, 0, 0, 0, 0];

% 3. Time-of-Use Grid Electricity Price ($/kWh) - expensive during peak hours
% Off-peak: $0.10, Mid-peak: $0.15, On-peak (5 PM - 9 PM): $0.35
Grid_Price_Buy = [0.10, 0.10, 0.10, 0.10, 0.10, 0.12, 0.12, 0.15, 0.15, 0.15, 0.15, 0.15, ...
                  0.15, 0.15, 0.15, 0.20, 0.35, 0.35, 0.35, 0.35, 0.20, 0.15, 0.12, 0.10];
              
% Grid Sellback Price (usually lower than buy price)
Grid_Price_Sell = Grid_Price_Buy * 0.6;

% --- Step 2: Define Optimization Bounds & Variables ---
% Vector structure for each hour: [P_grid_buy, P_grid_sell, P_batt_charge, P_batt_discharge]
n_vars_per_hour = 4;
n_vars = n_vars_per_hour * 24;

% Component Hardware Limits
Max_Grid_Cap = 150;     % Max power from grid (kW)
Max_Batt_Rate = 30;     % Max charge/discharge rate (kW)
Batt_Cap = 100;         % Total Battery Capacity (kWh)
Initial_SOC = 0.30;     % Starting at 30% State of Charge

% Set Lower Bounds (0) and Upper Bounds for all variables
lb = zeros(n_vars, 1);
ub = zeros(n_vars, 1);

for t = 1:24
    idx = (t-1)*4 + 1;
    ub(idx)   = Max_Grid_Cap;   % Max Buy Limit
    ub(idx+1) = Max_Grid_Cap;   % Max Sell Limit
    ub(idx+2) = Max_Batt_Rate;  % Max Charge Limit
    ub(idx+3) = Max_Batt_Rate;  % Max Discharge Limit
end

% --- Step 3: Cost Function & Power Balance Constraints ---
f = zeros(n_vars, 1);
Aeq = zeros(24, n_vars);
beq = zeros(24, 1);

for t = 1:24
    idx = (t-1)*4 + 1;
    
    % Objective: Minimize (Buy * Price_Buy) - (Sell * Price_Sell)
    f(idx)   = Grid_Price_Buy(t);   % Cost to buy
    f(idx+1) = -Grid_Price_Sell(t); % Revenue from selling (negative cost)
    f(idx+2) = 0.001;               % Tiny penalty to prevent cycle wear
    f(idx+3) = 0.001;               
    
    % Power Balance: P_grid_buy - P_grid_sell - P_batt_charge + P_batt_discharge = P_load - P_solar
    Aeq(t, idx)   = 1;   % P_grid_buy
    Aeq(t, idx+1) = -1;  % P_grid_sell
    Aeq(t, idx+2) = -1;  % P_batt_charge
    Aeq(t, idx+3) = 1;   % P_batt_discharge
    
    beq(t) = P_load(t) - P_solar(t);
end

% --- Step 4: Battery Capacity Tracking Constraints ---
% SOC(t) = Initial_SOC*Cap + Sum_up_to_t(Charge - Discharge)
A_spin = zeros(48, n_vars); 
b_spin = zeros(48, 1);

for t = 1:24
    row_max = (t-1)*2 + 1;
    row_min = (t-1)*2 + 2;
    
    % Accumulate battery transactions up to current hour 't'
    for k = 1:t
        k_idx = (k-1)*4 + 1;
        A_spin(row_max, k_idx+2) = 1;   % +Charge
        A_spin(row_max, k_idx+3) = -1;  % -Discharge
        
        A_spin(row_min, k_idx+2) = -1;  % Matrix inversion for lower bound
        A_spin(row_min, k_idx+3) = 1;
    end
    
    % Upper Bound: SOC <= 100% capacity
    b_spin(row_max) = Batt_Cap * (1.0 - Initial_SOC);
    % Lower Bound: SOC >= 20% minimum reserve
    b_spin(row_min) = Batt_Cap * (Initial_SOC - 0.20);
end

% --- Step 5: Run Linear Programming Optimization ---
options = optimoptions('linprog', 'Display', 'final');
[x_opt, total_cost] = linprog(f, A_spin, b_spin, Aeq, beq, lb, ub, options);

% Reshape results array for clean indexing
results = reshape(x_opt, [4, 24])';
P_grid_buy_opt  = results(:,1);
P_grid_sell_opt = results(:,2);
P_batt_chg_opt  = results(:,3);
P_batt_dis_opt  = results(:,4);

% Recalculate SOC Profile over the duration
SOC = zeros(24, 1);
current_energy = Initial_SOC * Batt_Cap;
for t = 1:24
    current_energy = current_energy + P_batt_chg_opt(t) - P_batt_dis_opt(t);
    SOC(t) = (current_energy / Batt_Cap) * 100;
end

% --- Step 6: Plot Operational Dispatch ---
figure;
subplot(2,1,1);
bar(hours, [P_solar', P_grid_buy_opt, P_batt_dis_opt], 'stacked');
hold on; plot(hours, P_load, 'r--', 'LineWidth', 2);
title('Optimal Microgrid Energy Dispatch Strategy');
xlabel('Hour of Day'); ylabel('Power (kW)');
legend('Solar Generation', 'Grid Power Bought', 'Battery Discharging', 'Net Load Demand');
grid on;

subplot(2,1,2);
plot(hours, SOC, 'b-o', 'LineWidth', 1.5);
title('Battery State of Charge (SOC) Trajectory');
xlabel('Hour of Day'); ylabel('SOC (%)');
grid on;
