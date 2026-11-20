// Creates the App Store / Google Play reviewer account with realistic sample data.
//   BASE_URL=http://45.158.199.215:3000 DEMO_PASSWORD='...' node scripts/seed-demo.js
// Refuses to run if the demo e-mail already exists.
const BASE = (process.env.BASE_URL || 'http://localhost:3000').replace(/\/$/, '') + '/api/v1';
const EMAIL = process.env.DEMO_EMAIL || 'demo@opero.app';
const PASSWORD = process.env.DEMO_PASSWORD;
const MANAGER_EMAIL = process.env.DEMO_MANAGER_EMAIL || 'demo.manager@opero.app';
if (!PASSWORD || PASSWORD.length < 8) {
  console.error('Set DEMO_PASSWORD (8+ characters).');
  process.exit(1);
}

let token = null;
async function call(method, path, body, form) {
  const headers = token ? { Authorization: `Bearer ${token}` } : {};
  let payload;
  if (form) payload = form;
  else if (body !== undefined) {
    headers['Content-Type'] = 'application/json';
    payload = JSON.stringify(body);
  }
  const res = await fetch(BASE + path, { method, headers, body: payload });
  const json = await res.json().catch(() => null);
  if (!res.ok) throw new Error(`${method} ${path} -> ${res.status} ${json && json.message}`);
  return json && json.data !== undefined ? json.data : json;
}

const day = (d) => {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), d).toISOString().slice(0, 10);
};
const today = new Date().getDate();
const pastDay = (d) => day(Math.min(d, today));

function minimalPdf(lines) {
  const text = lines.map((l, i) => `BT /F1 12 Tf 60 ${760 - i * 20} Td (${l}) Tj ET`).join('\n');
  const objs = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
    `<< /Length ${Buffer.byteLength(text)} >>\nstream\n${text}\nendstream`,
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  let pdf = '%PDF-1.4\n';
  const offsets = [];
  objs.forEach((o, i) => {
    offsets.push(Buffer.byteLength(pdf));
    pdf += `${i + 1} 0 obj\n${o}\nendobj\n`;
  });
  const xref = Buffer.byteLength(pdf);
  pdf += `xref\n0 ${objs.length + 1}\n0000000000 65535 f \n`;
  offsets.forEach((o) => { pdf += `${String(o).padStart(10, '0')} 00000 n \n`; });
  pdf += `trailer\n<< /Size ${objs.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(pdf, 'latin1');
}

(async () => {
  const reg = await fetch(BASE + '/auth/register', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: EMAIL, password: PASSWORD, fullName: 'Демо Администратор', phone: '+998 90 000-00-00', companyName: 'ООО «Демо Трейд»' }),
  });
  const regJson = await reg.json();
  if (reg.status !== 201) throw new Error(`register: ${regJson.message}`);
  token = regJson.accessToken;
  console.log('account created:', EMAIL);

  // Customers and suppliers
  const c1 = await call('POST', '/customers', { name: 'ООО «Альфа Строй»', phone: '+998 71 200-10-10', email: 'info@alfa-stroy.uz', address: 'Ташкент, ул. Навои, 12' });
  const c2 = await call('POST', '/customers', { name: 'ИП Каримов', phone: '+998 90 123-45-67' });
  const s1 = await call('POST', '/suppliers', { name: 'ООО «Текстиль Импорт»', contactPerson: 'Азиз Рахимов', phone: '+998 71 150-20-30' });

  // Products
  const products = [];
  for (const p of [
    { name: 'Ткань блэкаут, серая', categoryName: 'Ткани', unit: 'м', purchasePrice: 45000, sellingPrice: 68000, initialStock: 120, minStockLevel: 30 },
    { name: 'Тюль вуаль, белая', categoryName: 'Ткани', unit: 'м', purchasePrice: 22000, sellingPrice: 35000, initialStock: 200, minStockLevel: 50 },
    { name: 'Карниз алюминиевый 3 м', categoryName: 'Фурнитура', unit: 'шт', purchasePrice: 95000, sellingPrice: 150000, initialStock: 25, minStockLevel: 10 },
    { name: 'Рулонная штора 120×180', categoryName: 'Готовые изделия', unit: 'шт', purchasePrice: 180000, sellingPrice: 260000, initialStock: 8, minStockLevel: 10 },
    { name: 'Крючки для штор (уп. 50 шт)', categoryName: 'Фурнитура', unit: 'уп', purchasePrice: 12000, sellingPrice: 20000, initialStock: 60, minStockLevel: 15 },
  ]) products.push(await call('POST', '/inventory/products', p));

  // Delivery from the supplier, received into stock (creates a payable)
  await call('POST', '/shipments', { supplierId: s1.id, invoiceNumber: 'НК-1048', items: [{ productId: products[0].id, quantity: 50, unitPrice: 45000 }, { productId: products[2].id, quantity: 10, unitPrice: 95000 }] });

  // Sales: one paid in full, one partly paid (creates a receivable)
  await call('POST', '/sales', { customerId: c1.id, paymentMethod: 'bank', paidAmount: 1360000 + 1500000, items: [{ productId: products[0].id, quantity: 20, price: 68000 }, { productId: products[2].id, quantity: 10, price: 150000 }] });
  await call('POST', '/sales', { customerId: c2.id, paymentMethod: 'cash', paidAmount: 300000, items: [{ productId: products[3].id, quantity: 3, price: 260000 }] });

  // Income and expenses across the month
  for (const t of [
    { kind: 'income', amount: 12500000, paymentMethod: 'bank', customerName: 'ООО «Альфа Строй»', description: 'Предоплата по договору №24', date: pastDay(3) },
    { kind: 'income', amount: 4200000, paymentMethod: 'cash', customerName: 'Розничные продажи', description: 'Выручка магазина за неделю', date: pastDay(7) },
    { kind: 'income', amount: 6800000, paymentMethod: 'card', customerName: 'Розничные продажи', description: 'Оплаты картой за неделю', date: pastDay(14) },
    { kind: 'expense', amount: 3500000, paymentMethod: 'bank', category: 'Аренда', employeeName: 'ООО «Бизнес Центр»', description: 'Аренда склада и офиса', date: pastDay(5) },
    { kind: 'expense', amount: 9000000, paymentMethod: 'bank', category: 'Зарплата', employeeName: 'Сотрудники', description: 'Заработная плата за месяц', date: pastDay(10) },
    { kind: 'expense', amount: 850000, paymentMethod: 'cash', category: 'Транспорт и логистика', employeeName: 'Доставка', description: 'Доставка товара клиентам', date: pastDay(12) },
    { kind: 'expense', amount: 1200000, paymentMethod: 'card', category: 'Маркетинг и реклама', employeeName: 'Instagram Ads', description: 'Реклама в социальных сетях', date: pastDay(16) },
  ]) {
    const { kind, ...body } = t;
    await call('POST', `/finance/transactions/${kind}`, body);
  }

  // Deals at different stages
  await call('POST', '/deals', { title: 'Оснащение гостиницы «Сити»', customerName: 'Гостиница «Сити»', amount: 48000000, status: 'negotiation', description: 'Шторы и карнизы для 40 номеров' });
  await call('POST', '/deals', { title: 'Шторы для офиса', customerId: c1.id, amount: 7500000, status: 'proposal' });
  await call('POST', '/deals', { title: 'Детский сад №15', customerName: 'Детский сад №15', amount: 5200000, status: 'won' });

  // A second user so roles and task assignment are visible
  const manager = await call('POST', '/employees', { fullName: 'Дилноза Юсупова', email: MANAGER_EMAIL, password: PASSWORD, role: 'MANAGER', position: 'Менеджер по продажам', departmentName: 'Продажи', phone: '+998 93 555-12-12' });

  // Tasks
  const t1 = await call('POST', '/tasks', { title: 'Подготовить коммерческое предложение для гостиницы', description: 'Расчёт на 40 номеров, два варианта ткани', priority: 'high', assignedToId: manager.id, deadline: new Date(Date.now() + 3 * 86400000).toISOString() });
  await call('POST', '/tasks', { title: 'Провести инвентаризацию склада', priority: 'medium', deadline: new Date(Date.now() + 7 * 86400000).toISOString() });
  const t3 = await call('POST', '/tasks', { title: 'Оплатить поставку НК-1048', priority: 'medium' });
  await call('PUT', `/tasks/${t3.id}/status`, { status: 'done' });
  await call('POST', `/tasks/${t1.id}/comments`, { content: 'Клиент просит образцы тканей до пятницы' });

  // Documents
  const folder = await call('POST', '/documents/folders', { name: 'Договоры' });
  const form = new FormData();
  form.append('folderId', folder.id);
  form.append('file', new Blob([minimalPdf(['Opero demo document', 'Supply contract No. 24', 'Sample file for review'])], { type: 'application/pdf' }), 'Договор поставки №24.pdf');
  await call('POST', '/documents/upload', undefined, form);

  // Team chat: a few messages from both users, so the reviewer can try Reply / Report / Block.
  const ownerToken = token;
  const room = (await call('GET', '/chat/rooms'))[0];
  const login = await fetch(BASE + '/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: MANAGER_EMAIL, password: PASSWORD }) });
  const managerToken = (await login.json()).accessToken;
  for (const [who, text] of [
    [ownerToken, 'Доброе утро! Сегодня встреча с гостиницей «Сити» в 15:00'],
    [managerToken, 'Здравствуйте! Коммерческое предложение почти готово, отправлю до обеда'],
    [managerToken, 'Образцы тканей уже на складе, могу взять с собой'],
    [ownerToken, 'Отлично, спасибо!'],
  ]) {
    token = who;
    await call('POST', `/chat/rooms/${room.id}/messages`, { content: text });
  }
  token = ownerToken;

  const stats = await call('GET', '/dashboard/stats?period=month');
  console.log('done. Dashboard this month:', JSON.stringify({ balance: stats.totalBalance, income: stats.income, expenses: stats.expenses, sales: stats.sales, products: stats.totalProducts }));
})().catch((err) => {
  console.error('FAILED:', err.message);
  process.exit(1);
});
