# Data Model (POS)

SQLite via Floor, schema version 4 (`lib/database/database.dart`). Amounts are
stored in the primary currency; timestamps are epoch milliseconds.

```mermaid
erDiagram
    PRODUCT ||--o{ SALE_ITEM : "sold as"
    PRODUCT ||--o{ STOCK_MOVEMENT : "audited by"
    SALE ||--|{ SALE_ITEM : has
    CUSTOMER ||--o{ SALE : makes
    USER ||--o{ SALE : rings

    PRODUCT {
      int id PK
      string name
      string barcode "nullable, unique (enforced in app)"
      string category
      double price
      double cost
      int stock
      int lowStockThreshold
      bool trackStock
      bool active
    }

    SALE {
      int id PK "receipt number"
      int createdAt
      int customerId FK "nullable"
      int userId FK "cashier"
      double subtotal
      double discount
      double tax
      double total
      string paymentMethod "cash | card | other"
      double amountPaid
      double changeDue
      double exchangeRate "secondary rate at time of sale"
      string status "completed | refunded"
    }

    SALE_ITEM {
      int id PK
      int saleId FK "cascade delete"
      int productId "nullable, product may be deleted"
      string name "snapshot"
      int quantity
      double unitPrice "snapshot"
      double unitCost "snapshot, for profit"
      double lineTotal
    }

    STOCK_MOVEMENT {
      int id PK
      int productId
      int change "+in / -out"
      string reason "initial | sale | refund | restock | adjustment"
      int saleId "nullable"
      int userId "nullable"
    }

    CUSTOMER {
      int id PK
      string name
      string phone
      string email
      string notes
    }

    USER {
      int id PK
      string name
      string role "admin | cashier"
      string pinHash "sha256(salt:pin)"
      string pinSalt
      bool active
    }

    SETTING {
      string key PK
      string value
    }
```

## Invariants

- Stock only changes through `ProductDao.adjustStock`, `SaleDao.recordSale` and
  `SaleDao.refundSale`; each runs in one transaction and writes a
  `STOCK_MOVEMENT` row.
- Sale lines snapshot name, price and cost, so receipts and profit reports stay
  correct after a product is edited or deleted.
- Reports count only `status = completed` sales; refunds are reported separately.

## Upgrading from the original app (v1–v2)

`migrateLegacySchema` (`lib/database/migrations.dart`) copies `items` into
`products` (stock not tracked) and the `rate` row into the secondary-currency
settings (`L.L`). The old tables are kept, renamed to `legacy_items` /
`legacy_rate`. Covered by `test/database_test.dart`.
