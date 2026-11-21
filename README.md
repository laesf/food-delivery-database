# Food Delivery Database

Relational schema for a food delivery service, written for MySQL/MariaDB. Business rules such as order totals, allergen checks, review validation and rider workload are enforced in the database with triggers rather than in application code.

Built as a university databases project. Table and column names are in Italian.

## Schema

<img width="1838" height="1002" alt="Entity-relationship diagram" src="https://github.com/user-attachments/assets/3f7d3380-0b67-4563-8470-55cbcfd73b63" />

13 tables with primary keys (composite on the junction tables) and 13 foreign key constraints:

| Area | Tables |
| :--- | :--- |
| Customers | `cliente`, `alergene_utente` (customer allergens) |
| Restaurants and menu | `ristorante`, `categorie`, `ristorante_categoria`, `piatto` (dishes), `allergeni`, `alergene_piatto` (dish allergens) |
| Orders | `ordine`, `carrello` (order lines) |
| Riders | `rider`, `paga` (payments) |
| Reviews | `recensione`, limited to one per order by a unique key |

Prices are stored as `DECIMAL(10,2)`; a dish has a net price (`imponibile`) and a VAT rate (`iva`, percent).

## Triggers

`triggers.sql` defines 11 triggers. It drops them first, so it can be re-run.

| Trigger | Table | Behaviour |
| :--- | :--- | :--- |
| `carrello_before_insert` | `carrello` | Rejects a missing or non-positive quantity; fills in a missing price as net price plus VAT; rejects a dish containing an allergen registered for the customer |
| `carrello_after_insert`, `carrello_after_update`, `carrello_after_delete` | `carrello` | Recalculate the order total; when a line moves to another order, both totals are updated |
| `recensione_before_insert` | `recensione` | Allows a review only for a delivered order (`stato = 'consegnato'`); ratings must be between 1 and 5 |
| `recensione_before_update` | `recensione` | Same rating check; if the review is moved to another order, that order must be delivered |
| `recensione_after_insert`, `recensione_after_update`, `recensione_after_delete` | `recensione` | Recalculate the restaurant's average rating (`media_voti`); it is set to 0 when the restaurant has no reviews left |
| `ordine_after_insert` | `ordine` | Increments the assigned rider's active order counter (`impegnato`) if the order is active |
| `ordine_after_update` | `ordine` | Updates the counters when an order is reassigned, closed or reopened |

An order is active unless its status is `'consegnato'` (delivered) or `'annullato'` (cancelled). The two `ordine` triggers keep `rider.impegnato` equal to the number of active orders assigned to each rider.

Rule violations are raised with `SIGNAL SQLSTATE '45000'` and an error message.

## Setup

```bash
git clone https://github.com/laesf/food-delivery-database.git
cd food-delivery-database
mysql -e "CREATE DATABASE food_delivery"
mysql food_delivery < deliv_data.sql
mysql food_delivery < triggers.sql
```

Use `mariadb` instead of `mysql` on recent MariaDB versions, and add connection options (`-u`, `-p`, `-h`) as needed.

## Tests

`tests.sql` checks every trigger, including the rejected cases. Run it on an empty test database with the schema and triggers loaded:

```bash
mysql -e "CREATE DATABASE food_delivery_test"
mysql food_delivery_test < deliv_data.sql
mysql food_delivery_test < triggers.sql
mysql -t food_delivery_test < tests.sql
```

The script works inside a transaction that it rolls back, so no data is left behind. It prints each check and a summary of passed and failed checks.

Tested on MariaDB 13.0. MySQL has not been tested.

## Files

| File | Contents |
| :--- | :--- |
| `deliv_data.sql` | Tables, keys and foreign keys |
| `triggers.sql` | The 11 triggers |
| `tests.sql` | Trigger tests |

## Limitations

- `ordine.stato` is free text; only `'consegnato'` and `'annullato'` have a meaning in the triggers.
- The rider counter is maintained on order insert and update only. Deleting an active order, or editing `rider.impegnato` directly, leaves it out of sync.
