# Food Delivery Database System

A comprehensive relational database architecture optimized for the **Food Delivery** platform. This application includes DDL for data structure, strict referential integrity management, and a solid layer of business logic through **SQL Trigger** technology.

## Project Overview

This database is designed to manage the entire process of handling a home delivery order, managing complex entities and their relationships, such as:
* **Users & Customers:** Profile management and tracking of intolerances/allergens.
* **Restaurants & Dishes:** Menu and food category management; allergen tracking in dishes.
* **Riders:** Real-time workload tracking (assigned and ongoing orders).
* **Orders & Shopping Carts:** Product transaction management; total calculation; order status tracking.
* **Reviews:** Feedback with dynamic calculation of average ratings for restaurants.

## Repository Structure

The project is divided into two main files to separate the definition of the structure from the active logic:

* `deliv_data.sql`: Contains the **Data Definition Language (DDL)**. Creates tables, defines data types, primary keys (PK), and referential integrity constraints (Foreign Keys).
* `triggers.sql`: Contains the **advanced Data Manipulation Language (DML)**. Defines the active rules (Triggers) to automate and protect the system.

## Automated Business Logic (Triggers)

At the core of our system are 11 triggers that guarantee data accuracy and reliability without having to resort to backend calculations:

### Shopping Cart and Order Management

* **`cart_before_insert`**: Validates quantity, calculates the price per line, and *checks for any conflicts between the allergens in the dish and those reported by the customer*.
* **`carrello_after_insert` / `_update` / `_delete`**: Dynamically recalculate the total price of the associated order in real time each time the cart is modified.

### Review Management

* **`recensione_before_insert` / `_update`**: Restrict the insertion or modification of reviews *only* if the order is actually “delivered” and ensure that ratings are between 1 and 5.
* **`recensione_after_insert` / `_update` / `_delete`**: Automatically update the restaurant's `media_voti` by calculating the mathematical average of all active reviews.

### Fleet Management (Riders)

* **`order_after_insert`**: Automatically increments the `busy` counter of the rider assigned to the order.
* **`order_after_update`**: Dynamically manages changes

## Installation and Use

To test and deploy the database locally:

1. Run a **MySQL** or **MariaDB** server (for example, through XAMPP, MAMP, Docker, etc.).
2. Clone the repository:
   ```bash
   git clone [https://github.com/laesf/food-delivery-database.git](https://github.com/laesf/food-delivery-database.git)
   cd food-delivery-database

## Schema
<img width="1838" height="1002" alt="Diagramma_ER" src="https://github.com/user-attachments/assets/3f7d3380-0b67-4563-8470-55cbcfd73b63" />



