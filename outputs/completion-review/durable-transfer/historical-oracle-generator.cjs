const M = require("./electron-reference/app/ui/model.js");

function getOracle() {
  const date = "2026-01-15";
  
  // Scenario 1: Ordinary transfer
  const s1 = M.empty();
  s1.days[date] = {
    expenses: [],
    chickenUsed: 0,
    chickenLeft: 0,
    balance: 100000,
    totalOverride: null,
    remaining: { amount: 100000, dailySpent: 0, transferred: 0, salesTotal: 0 }
  };
  M.transferRemaining(s1, date, 20000, "t_ord", "2026-01-15T12:00:00Z");
  
  // Scenario 2: Transfer all
  const s2 = M.empty();
  s2.days[date] = {
    expenses: [],
    chickenUsed: 0,
    chickenLeft: 0,
    balance: 100000,
    totalOverride: null,
    remaining: { amount: 100000, dailySpent: 0, transferred: 0, salesTotal: 0 }
  };
  M.transferRemaining(s2, date, 100000, "t_all", "2026-01-15T12:00:00Z");

  // Scenario 3: Legacy unset total recovery
  const s3 = M.empty();
  s3.days[date] = {
    expenses: [{ id: "e1", categoryId: "market", amount: 20000, note: "", createdAt: date + "T10:00:00Z", funding: { source: "daily", dailyAmount: 20000, cashAmount: 0 } }],
    chickenUsed: 0,
    chickenLeft: 0,
    balance: null,
    totalOverride: null,
    remaining: { amount: 100000, dailySpent: 20000, transferred: 5000, salesTotal: 0 }
  };
  s3.transfers = [{ id: "t0", date, amount: 5000, createdAt: date + "T09:00:00Z" }];
  M.transferRemaining(s3, date, 30000, "t_rec", "2026-01-15T12:00:00Z");

  // Scenario 4: Subsequent dated effects
  const s4 = M.empty();
  s4.products = [{ id: "prod-1", name: "Kebab", code: "", group: "", unit: "plate", price: 10000, minStock: 0, trackStock: false, archived: false }];
  s4.days[date] = {
    expenses: [{ id: "e1", categoryId: "market", amount: 20000, note: "", createdAt: date + "T10:00:00Z", funding: { source: "daily", dailyAmount: 20000, cashAmount: 0 } }],
    chickenUsed: 0,
    chickenLeft: 0,
    balance: 100000,
    totalOverride: null,
    remaining: { amount: 100000, dailySpent: 20000, transferred: 0, salesTotal: 0 }
  };
  M.transferRemaining(s4, date, 20000, "t_mix_1", date + "T11:00:00Z");
  let s4_sales = M.completeSale(s4, { date, lines: [{ productId: "prod-1", quantity: 1 }], discount: 0, note: "", orderType: "صالة" }, "sale-1", date + "T12:00:00Z");
  s4_sales.days[date].expenses.push({ id: "e2", categoryId: "market", amount: 5000, note: "", createdAt: date + "T13:00:00Z", funding: { source: "daily", dailyAmount: 5000, cashAmount: 0 } });
  let s4_refund = M.returnSale(s4_sales, "sale-1", { date, reason: "return", lines: [{ productId: "prod-1", quantity: 1, restock: false }] }, "ret-1", date + "T14:00:00Z");
  M.transferRemaining(s4_refund, date, 15000, "t_mix_2", date + "T15:00:00Z");

  return {
    engine: "frozen model.js (Electron 44.5.1 / Node 24.21.0)",
    date,
    scenarios: {
      scenario1_ordinary: {
        description: "Ordinary transfer 20k from 100k available",
        remaining: M.remaining(s1, date),
        transferred: M.transferred(s1, date),
        balance: s1.days[date].balance,
        cashbox: M.cash(s1)
      },
      scenario2_transfer_all: {
        description: "Transfer-all 100k reaches zero remaining",
        remaining: M.remaining(s2, date),
        transferred: M.transferred(s2, date),
        balance: s2.days[date].balance,
        cashbox: M.cash(s2)
      },
      scenario3_legacy_unset_total: {
        description: "Recovery of unset total (null balance) to 125k before transfer, preserved after transfer",
        remaining: M.remaining(s3, date),
        transferred: M.transferred(s3, date),
        balance: s3.days[date].balance,
        cashbox: M.cash(s3)
      },
      scenario4_subsequent_dated_effects: {
        description: "Subsequent dated effects: transfer1 (20k) -> sale (10k) -> expense (5k) -> refund (10k) -> transfer2 (15k)",
        remaining: M.remaining(s4_refund, date),
        transferred: M.transferred(s4_refund, date),
        balance: s4_refund.days[date].balance,
        cashbox: M.cash(s4_refund),
        dailySpent: M.dailySpent(s4_refund, date),
        netSales: M.salesTotal(s4_refund, date)
      }
    }
  };
}

const fs = require("fs");
fs.writeFileSync("outputs/completion-review/durable-transfer/oracle.json", JSON.stringify(getOracle(), null, 2) + "\n");
