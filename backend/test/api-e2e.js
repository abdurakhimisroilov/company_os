// End-to-end API checks against a running server.
//   BASE_URL=http://localhost:3000 node test/api-e2e.js
// Creates its own throwaway accounts and deletes them at the end.
const fs = require('fs');
const os = require('os');
const path = require('path');

const BASE = (process.env.BASE_URL || 'http://localhost:3000').replace(/\/$/, '');
const API = `${BASE}/api/v1`;
const stamp = Date.now().toString(36);
let passed = 0;
const failures = [];

function check(name, cond, detail) {
  if (cond) {
    passed += 1;
    console.log(`  ✓ ${name}`);
  } else {
    failures.push(name);
    console.log(`  ✗ ${name}${detail !== undefined ? ` — ${JSON.stringify(detail)}` : ''}`);
  }
}

async function call(method, url, { token, body, form } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  let payload;
  if (form) payload = form;
  else if (body !== undefined) {
    headers['Content-Type'] = 'application/json';
    payload = JSON.stringify(body);
  }
  const res = await fetch(url.startsWith('http') ? url : `${API}${url}`, { method, headers, body: payload });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch (e) { /* binary or empty */ }
  return { status: res.status, json, text };
}

const data = (r) => (r.json && r.json.data !== undefined ? r.json.data : r.json);

async function register(label) {
  const email = `e2e_${label}_${stamp}@example.test`;
  const r = await call('POST', '/auth/register', { body: { email, password: 'Secret123', fullName: `E2E ${label}` } });
  return { email, password: 'Secret123', token: r.json && r.json.accessToken, refresh: r.json && r.json.refreshToken, user: r.json && r.json.user, status: r.status };
}

async function main() {
  console.log(`\nCOMPANY OS API e2e against ${API}\n`);

  console.log('Auth');
  const anon = await call('GET', '/finance/accounts');
  check('business routes reject requests without a token', anon.status === 401, anon.status);
  const a = await register('a');
  check('register returns tokens and a SUPER_ADMIN user', a.status === 201 && !!a.token && a.user.role === 'SUPER_ADMIN', a.status);
  const dupe = await call('POST', '/auth/register', { body: { email: a.email, password: 'Secret123', fullName: 'Dup' } });
  check('duplicate email is rejected with a message', dupe.status === 400 && /уже зарегистрирован/.test(dupe.json.message), dupe.json);
  const bad = await call('POST', '/auth/login', { body: { email: a.email, password: 'wrong-password' } });
  check('wrong password is rejected', bad.status === 401, bad.status);
  for (const master of ['Admin123!', 'Employee123!', '900622725']) {
    const r = await call('POST', '/auth/login', { body: { email: a.email, password: master } });
    check(`old master password "${master}" no longer works`, r.status === 401, r.status);
  }
  const login = await call('POST', '/auth/login', { body: { email: a.email, password: a.password } });
  check('login with the right password works', login.status === 200 && !!login.json.accessToken, login.status);
  const T = login.json.accessToken;
  const me = await call('GET', '/auth/me', { token: T });
  check('/auth/me returns the signed-in user', me.status === 200 && me.json.email === a.email, me.json);
  check('/auth/me never exposes password hashes', !/password/i.test(me.text));
  const refreshed = await call('POST', '/auth/refresh', { body: { refreshToken: login.json.refreshToken } });
  check('refresh token issues a new access token', refreshed.status === 200 && !!refreshed.json.accessToken, refreshed.status);
  const refreshWithAccess = await call('POST', '/auth/refresh', { body: { refreshToken: T } });
  check('an access token cannot be used as a refresh token', refreshWithAccess.status === 401, refreshWithAccess.status);

  console.log('\nFinance: income of 1 000 000 UZS');
  const startStats = (await call('GET', '/dashboard/stats?period=month', { token: T })).json;
  check('new organization starts at zero', startStats.totalBalance === 0 && startStats.income === 0, startStats);
  const accounts = data(await call('GET', '/finance/accounts', { token: T }));
  check('organization has cash and bank accounts', accounts.length === 2 && accounts.some((x) => x.type === 'CASH') && accounts.some((x) => x.type === 'BANK'), accounts.map((x) => x.type));

  const today = new Date().toISOString().slice(0, 10);
  const income = await call('POST', '/finance/transactions/income', {
    token: T,
    body: { amount: 1000000, type: 'income', paymentMethod: 'bank', description: 'все ок прошло', customerName: 'Клиент1', date: `${today}T00:00:00.000`, category: 'Поступление от клиента' },
  });
  const inc = data(income);
  check('income is saved (201)', income.status === 201 && !!inc.id, income.json);
  check('amount is stored exactly', inc.amount === 1000000, inc.amount);
  check('payment method is stored', inc.payment_method === 'bank' && inc.account_type === 'BANK', [inc.payment_method, inc.account_type]);
  check('customer, description, category and date are stored', inc.counterparty_name === 'Клиент1' && inc.description === 'все ок прошло'
    && inc.category === 'Поступление от клиента' && String(inc.transaction_date).slice(0, 10) === today, inc);

  const afterIncome = (await call('GET', '/dashboard/stats?period=month', { token: T })).json;
  check('dashboard income shows 1 000 000', afterIncome.income === 1000000, afterIncome.income);
  check('dashboard balance shows 1 000 000', afterIncome.totalBalance === 1000000, afterIncome.totalBalance);
  const todayStats = (await call('GET', '/dashboard/stats?period=today', { token: T })).json;
  check('"today" period also includes it', todayStats.income === 1000000, todayStats.income);

  const zero = await call('POST', '/finance/transactions/income', { token: T, body: { amount: 0, paymentMethod: 'cash' } });
  check('zero amount is rejected', zero.status === 400, zero.status);
  const negative = await call('POST', '/finance/transactions/expense', { token: T, body: { amount: -5, paymentMethod: 'cash' } });
  check('negative amount is rejected', negative.status === 400, negative.status);

  console.log('\nFinance: persistence and expense');
  const relogin = await call('POST', '/auth/login', { body: { email: a.email, password: a.password } });
  const T2 = relogin.json.accessToken;
  const list = await call('GET', '/finance/transactions?page=1&limit=50', { token: T2 });
  check('transaction is still there after signing in again', data(list).some((t) => t.id === inc.id), data(list).length);
  check('list reports the total count', list.json.meta.total === 1, list.json.meta);

  const expense = await call('POST', '/finance/transactions/expense', {
    token: T2,
    body: { amount: 250000, type: 'expense', category: 'Аренда', paymentMethod: 'bank', description: 'Аренда офиса', employeeName: 'Арендодатель', date: `${today}T00:00:00.000` },
  });
  check('expense is saved (201)', expense.status === 201 && data(expense).category === 'Аренда', expense.json);
  const afterExpense = (await call('GET', '/dashboard/stats?period=month', { token: T2 })).json;
  check('balance is recalculated: 1 000 000 − 250 000 = 750 000', afterExpense.totalBalance === 750000, afterExpense.totalBalance);
  check('dashboard expenses show 250 000', afterExpense.expenses === 250000, afterExpense.expenses);
  const accountsAfter = data(await call('GET', '/finance/accounts', { token: T2 }));
  check('bank account holds 750 000 and cash holds 0', accountsAfter.find((x) => x.type === 'BANK').balance === 750000 && accountsAfter.find((x) => x.type === 'CASH').balance === 0, accountsAfter.map((x) => [x.type, x.balance]));
  const onlyIncome = data(await call('GET', '/finance/transactions?type=income', { token: T2 }));
  check('type filter returns only incomes', onlyIncome.length === 1 && onlyIncome[0].type === 'INCOME', onlyIncome.map((t) => t.type));

  const bank = accountsAfter.find((x) => x.type === 'BANK');
  const cash = accountsAfter.find((x) => x.type === 'CASH');
  const transfer = await call('POST', '/finance/transactions/transfer', { token: T2, body: { fromAccountId: bank.id, toAccountId: cash.id, amount: 100000 } });
  check('transfer between accounts works', transfer.status === 201, transfer.json);
  const overdraw = await call('POST', '/finance/transactions/transfer', { token: T2, body: { fromAccountId: cash.id, toAccountId: bank.id, amount: 999999999 } });
  check('transfer larger than the balance is rejected', overdraw.status === 400, overdraw.status);
  const afterTransfer = (await call('GET', '/dashboard/stats?period=month', { token: T2 })).json;
  check('transfer does not change total balance, income or expenses', afterTransfer.totalBalance === 750000 && afterTransfer.income === 1000000 && afterTransfer.expenses === 250000, afterTransfer);

  const report = data(await call('GET', '/reports/financial?period=month', { token: T2 }));
  check('financial report uses the same records', report.income === 1000000 && report.expenses === 250000 && report.netProfit === 750000, report);
  check('report has a real time series and expense categories', report.monthlyData.length >= 1 && report.expensesByCategory[0].category === 'Аренда', [report.monthlyData, report.expensesByCategory]);

  console.log('\nInventory');
  const created = await call('POST', '/inventory/products', {
    token: T2,
    body: { name: 'Тестовый товар', sku: `SKU-${stamp}`, sellingPrice: 5000, purchasePrice: 3000, unit: 'шт', minStockLevel: 5, categoryName: 'Тест-категория', initialStock: 10 },
  });
  const product = data(created);
  check('product is created with initial stock 10', created.status === 201 && product.quantity === 10, created.json);
  check('category was created and linked by name', product.category_name === 'Тест-категория', product.category_name);
  const dupSku = await call('POST', '/inventory/products', { token: T2, body: { name: 'Дубль', sku: `SKU-${stamp}` } });
  check('duplicate SKU is rejected with a message', dupSku.status === 400, dupSku.status);
  const found = data(await call('GET', `/inventory/products?search=${encodeURIComponent('Тестовый')}`, { token: T2 }));
  check('search finds the product', found.length === 1 && found[0].id === product.id, found.length);
  const none = data(await call('GET', '/inventory/products?search=zzzzzz-not-there', { token: T2 }));
  check('search with no match returns nothing', none.length === 0, none.length);
  const byCategory = data(await call('GET', `/inventory/products?categoryId=${product.category_id}`, { token: T2 }));
  check('category filter works', byCategory.length === 1, byCategory.length);
  const edited = await call('PATCH', `/inventory/products/${product.id}`, { token: T2, body: { name: 'Тестовый товар 2', sellingPrice: 6000 } });
  check('product can be edited', edited.status === 200 && data(edited).name === 'Тестовый товар 2' && data(edited).selling_price === 6000, edited.json);
  const stockIn = await call('POST', '/inventory/adjust', { token: T2, body: { productId: product.id, type: 'in', quantity: 5, notes: 'Приход' } });
  check('stock in: 10 + 5 = 15', stockIn.status === 201 && data(stockIn).quantity === 15, stockIn.json);
  const stockOut = await call('POST', '/inventory/adjust', { token: T2, body: { productId: product.id, type: 'out', quantity: 3, notes: 'Списание' } });
  check('stock out: 15 − 3 = 12', stockOut.status === 201 && data(stockOut).quantity === 12, stockOut.json);
  const tooMuch = await call('POST', '/inventory/adjust', { token: T2, body: { productId: product.id, type: 'out', quantity: 1000 } });
  check('cannot write off more than is in stock', tooMuch.status === 400, tooMuch.status);
  const movements = data(await call('GET', `/inventory/movements?productId=${product.id}`, { token: T2 }));
  check('every stock change has a movement record (3)', movements.length === 3 && movements[0].balance_after === 12, movements.map((m) => [m.type, m.quantity, m.balance_after]));
  const stockStats = (await call('GET', '/dashboard/stats', { token: T2 })).json;
  check('dashboard stock value = 12 × 3000', stockStats.stockBalance === 36000 && stockStats.totalProducts === 1, [stockStats.stockBalance, stockStats.totalProducts]);

  console.log('\nSales and shipments');
  const supplier = data(await call('POST', '/suppliers', { token: T2, body: { name: 'Поставщик Тест', phone: '+998900000000' } }));
  const shipment = await call('POST', '/shipments', { token: T2, body: { supplierId: supplier.id, items: [{ productId: product.id, quantity: 8, unitPrice: 4000 }] } });
  check('shipment is received and stock grows to 20', shipment.status === 201 && data(await call('GET', `/inventory/products/${product.id}`, { token: T2 })).quantity === 20, shipment.json);
  const supplierDebts = data(await call('GET', '/finance/supplier-debts', { token: T2 }));
  check('shipment creates a payable of 32 000', supplierDebts.length === 1 && supplierDebts[0].amount === 32000, supplierDebts);
  const fakeItem = await call('POST', '/sales', { token: T2, body: { customerName: 'X', items: [{ productId: 'prod_1', quantity: 1, price: 1 }] } });
  check('sale with an invented product id is rejected clearly', fakeItem.status === 400, fakeItem.status);
  const sale = await call('POST', '/sales', { token: T2, body: { customerName: 'Покупатель Тест', paymentMethod: 'cash', paidAmount: 6000, items: [{ productId: product.id, quantity: 2, price: 6000 }] } });
  const saleRow = data(sale);
  check('sale is saved, half paid', sale.status === 201 && saleRow.totalAmount === 12000 && saleRow.paymentStatus === 'partial', sale.json);
  check('sale deducts stock: 20 − 2 = 18', data(await call('GET', `/inventory/products/${product.id}`, { token: T2 })).quantity === 18);
  const custDebts = data(await call('GET', '/finance/customer-debts', { token: T2 }));
  check('unpaid half becomes a receivable of 6 000', custDebts.length === 1 && custDebts[0].amount === 6000, custDebts);
  const payDebt = await call('POST', '/finance/debts/pay', { token: T2, body: { debtId: custDebts[0].id, type: 'receivable', amount: 6000, paymentMethod: 'cash' } });
  check('receivable can be paid off', payDebt.status === 201 && data(await call('GET', '/finance/customer-debts', { token: T2 })).length === 0, payDebt.json);
  const oversell = await call('POST', '/sales', { token: T2, body: { customerName: 'Покупатель Тест', paidAmount: 0, items: [{ productId: product.id, quantity: 5000, price: 1 }] } });
  check('cannot sell more than is in stock', oversell.status === 400, oversell.status);

  console.log('\nDocuments and attachments');
  const tmp = path.join(os.tmpdir(), `e2e-${stamp}.txt`);
  fs.writeFileSync(tmp, 'company os e2e document');
  const mkForm = (extra = {}) => {
    const f = new FormData();
    f.append('file', new Blob([fs.readFileSync(tmp)], { type: 'text/plain' }), 'отчёт.txt');
    Object.entries(extra).forEach(([k, v]) => f.append(k, v));
    return f;
  };
  const up = await call('POST', '/files/upload', { token: T2, form: mkForm() });
  check('file upload returns a URL', up.status === 200 && /\/uploads\//.test(up.json.url), up.json);
  const open = await call('GET', up.json.url.startsWith('http') ? up.json.url : `${BASE}${up.json.url}`);
  check('uploaded file can be opened and has the same content', open.status === 200 && open.text === 'company os e2e document', open.status);
  const withDoc = await call('POST', '/finance/transactions/income', { token: T2, body: { amount: 1, paymentMethod: 'cash', documentUrl: up.json.url, documentName: 'отчёт.txt' } });
  check('attachment is saved on the transaction', withDoc.status === 201 && /\/uploads\//.test(data(withDoc).document_url) && data(withDoc).document_name === 'отчёт.txt', data(withDoc));
  const folder = data(await call('POST', '/documents/folders', { token: T2, body: { name: 'Договоры' } }));
  const doc = await call('POST', '/documents/upload', { token: T2, form: mkForm({ folderId: folder.id }) });
  check('document is uploaded into a folder with its real name', doc.status === 201 && data(doc).name === 'отчёт.txt' && data(doc).sizeBytes > 0, doc.json);
  const docs = data(await call('GET', `/documents/files?folderId=${folder.id}`, { token: T2 }));
  check('document is listed and still downloadable', docs.length === 1 && (await call('GET', docs[0].url.startsWith('http') ? docs[0].url : `${BASE}${docs[0].url}`)).status === 200);
  const noFile = await call('POST', '/documents/upload', { token: T2, form: (() => { const f = new FormData(); f.append('fileName', 'fake.pdf'); return f; })() });
  check('"upload" without a file is rejected', noFile.status === 400, noFile.status);
  const delDoc = await call('DELETE', `/documents/files/${docs[0].id}`, { token: T2 });
  const gone = await call('GET', docs[0].url.startsWith('http') ? docs[0].url : `${BASE}${docs[0].url}`);
  check('document can be deleted and its file is removed', delDoc.status === 200 && gone.status === 404, [delDoc.status, gone.status]);

  console.log('\nTasks');
  const task = await call('POST', '/tasks', { token: T2, body: { title: 'Проверить отчёт', description: 'e2e', priority: 'high', deadline: new Date(Date.now() + 86400000).toISOString() } });
  const taskRow = data(task);
  check('task is created and assigned', task.status === 201 && taskRow.status === 'todo' && !!taskRow.assignedToName, task.json);
  const att = await call('POST', `/tasks/${taskRow.id}/attachments`, { token: T2, form: mkForm() });
  const moved = await call('PUT', `/tasks/${taskRow.id}/status`, { token: T2, body: { status: 'done' } });
  check('task status change is saved with progress 100', moved.status === 200 && data(moved).status === 'done' && data(moved).progress === 100, moved.json);
  await call('POST', `/tasks/${taskRow.id}/comments`, { token: T2, body: { content: 'Готово' } });
  const taskFull = data(await call('GET', `/tasks/${taskRow.id}`, { token: T2 }));
  check('task detail returns comment and attachment', att.status === 201 && taskFull.comments.length === 1 && taskFull.comments[0].content === 'Готово' && taskFull.attachments.length === 1, taskFull);

  console.log('\nOrganizations and data isolation');
  const orgA = data(await call('GET', '/companies/current', { token: T2 }));
  const newOrg = await call('POST', '/companies', { token: T2, body: { name: `Вторая организация ${stamp}` } });
  const orgB = data(newOrg);
  check('new organization is created and becomes current', newOrg.status === 201 && orgB.is_current === true, newOrg.json);
  const listOrgs = data(await call('GET', '/companies', { token: T2 }));
  check('organizations list shows both, new one current', listOrgs.length === 2 && listOrgs[0].id === orgB.id && listOrgs[0].is_current, listOrgs.map((c) => [c.name, c.is_current]));
  const bStats = (await call('GET', '/dashboard/stats', { token: T2 })).json;
  check('new organization has no money, products or tasks', bStats.totalBalance === 0 && bStats.income === 0 && bStats.totalProducts === 0 && bStats.pendingTasks === 0, bStats);
  check('new organization has no transactions or products', data(await call('GET', '/finance/transactions', { token: T2 })).length === 0 && data(await call('GET', '/inventory/products', { token: T2 })).length === 0);
  const crossRead = await call('GET', `/inventory/products/${product.id}`, { token: T2 });
  check('a record from the other organization cannot be opened by id', crossRead.status === 404, crossRead.status);
  await call('POST', '/finance/transactions/income', { token: T2, body: { amount: 500, paymentMethod: 'cash' } });
  const back = await call('POST', '/companies/switch', { token: T2, body: { companyId: orgA.id } });
  check('switching back works', back.status === 200, back.json);
  const aStats = (await call('GET', '/dashboard/stats', { token: T2 })).json;
  check('first organization shows its own figures again', aStats.income === 1012001 && aStats.totalProducts === 1, [aStats.income, aStats.totalProducts]);
  const afterRelogin = await call('POST', '/auth/login', { body: { email: a.email, password: a.password } });
  check('selected organization persists across sign-in', data(await call('GET', '/companies/current', { token: afterRelogin.json.accessToken })).id === orgA.id);

  const b = await register('b');
  check('a second user gets their own empty organization', (await call('GET', '/dashboard/stats', { token: b.token })).json.totalBalance === 0 && data(await call('GET', '/inventory/products', { token: b.token })).length === 0);
  check('second user cannot see the first user\'s organizations', data(await call('GET', '/companies', { token: b.token })).length === 1);
  const hijack = await call('POST', '/companies/switch', { token: b.token, body: { companyId: orgA.id } });
  check('second user cannot switch into a foreign organization', hijack.status === 404, hijack.status);
  check('second user cannot open a foreign transaction list', data(await call('GET', '/finance/transactions', { token: b.token })).length === 0);
  check('employees list is limited to the own organization', data(await call('GET', '/employees', { token: b.token })).length === 1);
  check('employees list never exposes password hashes', !/password/i.test((await call('GET', '/employees', { token: T2 })).text));
  const notes = data(await call('GET', '/notifications', { token: b.token }));
  check('notifications are per user', notes.every((n) => n.user_id === b.user.id), notes.length);

  const delOrg = await call('DELETE', `/companies/${orgB.id}`, { token: T2 });
  check('an organization can be deleted by its owner', delOrg.status === 200 && data(await call('GET', '/companies', { token: T2 })).length === 1, delOrg.json);
  const delLast = await call('DELETE', `/companies/${orgA.id}`, { token: T2 });
  check('the last organization cannot be deleted', delLast.status === 400, delLast.status);

  console.log('\nEmployees, password, account deletion');
  const emp = await call('POST', '/employees', { token: T2, body: { fullName: 'Сотрудник Тест', email: `e2e_emp_${stamp}@example.test`, role: 'EMPLOYEE', position: 'Менеджер', departmentName: 'Продажи' } });
  check('employee is added with a one-time password', emp.status === 201 && typeof emp.json.temporaryPassword === 'string' && emp.json.temporaryPassword.length >= 8, emp.json);
  const empLogin = await call('POST', '/auth/login', { body: { email: `e2e_emp_${stamp}@example.test`, password: emp.json.temporaryPassword } });
  check('employee can sign in and sees the same organization', empLogin.status === 200 && (await call('GET', '/dashboard/stats', { token: empLogin.json.accessToken })).json.income === 1012001);
  const empAdmin = await call('POST', '/employees', { token: empLogin.json.accessToken, body: { fullName: 'X', email: `x_${stamp}@example.test` } });
  check('a regular employee cannot add employees', empAdmin.status === 403, empAdmin.status);
  const changed = await call('POST', '/auth/change-password', { token: T2, body: { currentPassword: a.password, newPassword: 'NewSecret456' } });
  check('password change works and returns fresh tokens', changed.status === 200 && !!changed.json.accessToken, changed.json);
  check('old password stops working', (await call('POST', '/auth/login', { body: { email: a.email, password: a.password } })).status === 401);
  check('sessions opened before the change are closed', (await call('GET', '/auth/me', { token: T2 })).status === 401);
  const T3 = changed.json.accessToken;
  const wrongDel = await call('DELETE', '/auth/account', { token: T3, body: { password: 'nope' } });
  check('account deletion requires the password', wrongDel.status === 400, wrongDel.status);
  const del = await call('DELETE', '/auth/account', { token: T3, body: { password: 'NewSecret456' } });
  check('account is deleted', del.status === 200, del.json);
  check('deleted account can no longer sign in or use its token', (await call('POST', '/auth/login', { body: { email: a.email, password: 'NewSecret456' } })).status === 401 && (await call('GET', '/auth/me', { token: T3 })).status === 401);
  check('uploaded files of the deleted organization are removed', (await call('GET', up.json.url.startsWith('http') ? up.json.url : `${BASE}${up.json.url}`)).status === 404);

  await call('DELETE', '/auth/account', { token: b.token, body: { password: b.password } });
  await call('DELETE', '/auth/account', { token: empLogin.json.accessToken, body: { password: emp.json.temporaryPassword } });
  fs.unlinkSync(tmp);

  console.log(`\n${passed} passed, ${failures.length} failed`);
  if (failures.length) {
    failures.forEach((f) => console.log(`  FAILED: ${f}`));
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('\nTest run crashed:', err);
  process.exit(1);
});
