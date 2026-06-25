# Microgrid Energy Management System (EMS) Using Linear Programming

A MATLAB optimization framework designed to minimize the daily operating costs of a localized smart microgrid by automating power dispatch decisions over a 24-hour horizon.

## Project Overview
The system models a grid-connected microgrid equipped with a Solar PV array and a Battery Energy Storage System (BESS) serving a residential load profile. Using Time-of-Use (ToU) electricity pricing schemes, the EMS formulates a Linear Programming (LP) problem to dynamically manage energy sourcing to minimize financial costs while strictly enforcing physical grid constraints.

## Optimization Formulation
* **Objective Function:** Minimize total net electricity cost (buying from utility grid vs. selling surplus solar generation back to the grid).
* **Equality Constraints:** Power balancing at each hourly step (Sourced Power = Demand Power).
* **Inequality Constraints:** Real-time state-of-charge (SOC) tracking limits, battery charging/discharging C-rates, and utility tie-line power capacity boundaries.

## Optimization Results
The linear programming model successfully demonstrates **peak shaving** and **load shifting**. The system automatically commands the battery to store cheap solar energy during the midday hours and discharges it during peak pricing periods (5:00 PM – 9:00 PM) to shield the microgrid from high tariff rates.

![Operational Dispatch](microgrid.png)

## Requirements & Execution
1. Requires MATLAB and the **Optimization Toolbox**.
2. Run `microgrid_ems.m` to compute the optimal matrix vector solution and view the resulting dispatch schedules.
