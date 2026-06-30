---
name: "pizza order item query"
created: "2026-06-30T10:34:04.683Z"
status: pending
---

# Plan: Pizza Order Item Formatter

## Context

Tables in `TIL_PLAYGROUND.CS2_PIZZA_RUNNER`:

| Table            | Key Columns                                                                                              |
| ---------------- | -------------------------------------------------------------------------------------------------------- |
| CUSTOMER\_ORDERS | ORDER\_ID, CUSTOMER\_ID, PIZZA\_ID, EXCLUSIONS (varchar, comma-sep IDs), EXTRAS (varchar, comma-sep IDs) |
| PIZZA\_NAMES     | PIZZA\_ID, PIZZA\_NAME ("Meatlovers", "Vegetarian")                                                      |
| PIZZA\_TOPPINGS  | TOPPING\_ID, TOPPING\_NAME                                                                               |

Data quirks:

- EXCLUSIONS/EXTRAS contain empty strings `''`, literal text `'null'`, or comma-separated IDs like `'1, 5'`
- 14 rows total, no unique row key -- need `ROW_NUMBER()` or use a CTE with a synthetic row ID

## Approach

Use a CTE-based query:

1. Assign a unique `ROW_ID` to each customer\_orders row (ROW\_NUMBER)
2. Use `LATERAL SPLIT_TO_TABLE` to explode exclusion IDs and extra IDs into rows
3. Join each to `PIZZA_TOPPINGS` to get topping names
4. `LISTAGG` the topping names back per ROW\_ID for exclusions and extras separately
5. Concatenate: `pizza_name || optional ' - Exclude ...' || optional ' - Extra ...'`

Note: The table stores "Meatlovers" but the desired output format is "Meat Lovers". The query will use a CASE or REPLACE to format.

## SQL Sketch

```sql
WITH numbered_orders AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY order_id, customer_id, pizza_id) AS row_id,
        *
    FROM TIL_PLAYGROUND.CS2_PIZZA_RUNNER.CUSTOMER_ORDERS
),
exclusions AS (
    SELECT
        o.row_id,
        LISTAGG(t.topping_name, ', ') WITHIN GROUP (ORDER BY t.topping_id) AS excluded
    FROM numbered_orders o,
        LATERAL SPLIT_TO_TABLE(o.exclusions, ', ') s
    JOIN TIL_PLAYGROUND.CS2_PIZZA_RUNNER.PIZZA_TOPPINGS t
        ON TRY_CAST(s.value AS INT) = t.topping_id
    WHERE o.exclusions IS NOT NULL
      AND o.exclusions NOT IN ('', 'null')
    GROUP BY o.row_id
),
extras AS (
    SELECT
        o.row_id,
        LISTAGG(t.topping_name, ', ') WITHIN GROUP (ORDER BY t.topping_id) AS extra
    FROM numbered_orders o,
        LATERAL SPLIT_TO_TABLE(o.extras, ', ') s
    JOIN TIL_PLAYGROUND.CS2_PIZZA_RUNNER.PIZZA_TOPPINGS t
        ON TRY_CAST(s.value AS INT) = t.topping_id
    WHERE o.extras IS NOT NULL
      AND o.extras NOT IN ('', 'null')
    GROUP BY o.row_id
)
SELECT
    o.order_id,
    o.customer_id,
    o.pizza_id,
    pn.pizza_name
        || COALESCE(' - Exclude ' || ex.excluded, '')
        || COALESCE(' - Extra ' || xt.extra, '')
    AS order_item
FROM numbered_orders o
JOIN TIL_PLAYGROUND.CS2_PIZZA_RUNNER.PIZZA_NAMES pn ON o.pizza_id = pn.pizza_id
LEFT JOIN exclusions ex ON o.row_id = ex.row_id
LEFT JOIN extras xt ON o.row_id = xt.row_id
ORDER BY o.order_id, o.row_id;
```

## Verification

Expected output for known rows:

- Row with order\_id=1, pizza\_id=1, no exclusions/extras -> "Meatlovers"
- Row with order\_id=4, pizza\_id=1, exclusions='4' -> "Meatlovers - Exclude Cheese"
- Row with order\_id=9, pizza\_id=1, exclusions='4', extras='1, 5' -> "Meatlovers - Exclude Cheese - Extra Bacon, Chicken"
- Row with order\_id=10, pizza\_id=1, exclusions='2, 6', extras='1, 4' -> "Meatlovers - Exclude BBQ Sauce, Mushrooms - Extra Bacon, Cheese"

## Critical Files

- TIL\_PLAYGROUND.CS2\_PIZZA\_RUNNER.CUSTOMER\_ORDERS - source table
- TIL\_PLAYGROUND.CS2\_PIZZA\_RUNNER.PIZZA\_TOPPINGS - topping ID to name lookup
- TIL\_PLAYGROUND.CS2\_PIZZA\_RUNNER.PIZZA\_NAMES - pizza ID to name lookup
