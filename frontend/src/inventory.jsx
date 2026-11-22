import { amount, Back, Button, dateTime, DetailList, Empty, ErrorSummary, Field, Filters,
  MaterialIcon, movementTypes, PageHeading, Pagination, PostForm, queryPath, routes, Table } from "./ui";

const productOptions = rows => rows.map(row => ({ value: row.id, label: row.name + " · " + row.sku + " (" + row.unit + ")" }));
const warehouseOptions = rows => rows.map(row => ({ value: row.id, label: row.name }));
const typeOptions = Object.entries(movementTypes).map(([value, label]) => ({ value, label }));

function PairFilters({ products, warehouses, filters }) {
  return <>
    <Field label="Товар" name="product_id" value={filters.product_id} options={productOptions(products)} placeholder="Все товары" />
    <Field label="Склад" name="warehouse_id" value={filters.warehouse_id} options={warehouseOptions(warehouses)} placeholder="Все склады" />
  </>;
}

function NewMovement({ type, pair = {} }) {
  return <Button href={queryPath(routes.movements + "/new", { ...pair, movement_type: type })} secondary={type === "issue"}>
    {type === "receipt" ? "＋ Приход" : "− Расход"}
  </Button>;
}

export function Balances({ rows, filters, pagination, products, warehouses, icons }) {
  return <>
    <PageHeading title="Остатки" description="Доступное количество товаров по складам"
      actions={<><NewMovement type="receipt" pair={filters} /><NewMovement type="issue" pair={filters} /></>} />
    <Filters path={routes.balances} filters={filters} searchPlaceholder="Товар, артикул или склад">
      <PairFilters products={products} warehouses={warehouses} filters={filters} />
    </Filters>
    {rows.length ? <Table label="Остатки" headers={["Товар", "Артикул", "Склад", "Остаток", "Минимум"]}
      rows={rows.map(row => ({
        id: row.id,
        cells: [
          <a className="row-link" href={routes.balances + "/" + row.id}><MaterialIcon name={row.product.name} icons={icons} />{row.product.name}</a>,
          row.product.sku, row.warehouse.name,
          <span className={Number(row.quantity) < Number(row.minimum_quantity) ? "below" : "numeric"}>{amount(row.quantity)} {row.product.unit}</span>,
          amount(row.minimum_quantity) + " " + row.product.unit,
        ],
      }))} /> : <Empty title="Остатков по запросу нет" description="Проверьте фильтры или оформите первое поступление." />}
    <Pagination path={routes.balances} filters={filters} page={pagination} />
  </>;
}

export function Balance({ record, icons }) {
  const pair = { product_id: record.product.id, warehouse_id: record.warehouse.id };
  return <>
    <Back href={routes.balances}>Остатки</Back>
    <PageHeading title={record.product.name} description={record.warehouse.name + " · " + record.product.sku}
      actions={<><NewMovement type="receipt" pair={pair} /><NewMovement type="issue" pair={pair} /></>} />
    <section className="panel">
      <div className="stock-number"><MaterialIcon name={record.product.name} icons={icons} /><strong>{amount(record.quantity)} {record.product.unit}</strong></div>
      <DetailList fields={[
        ["Минимальный остаток", amount(record.minimum_quantity) + " " + record.product.unit],
        ["Склад", <a href={routes.warehouses + "/" + record.warehouse.id}>{record.warehouse.name}</a>],
        ["Товар", <a href={routes.products + "/" + record.product.id}>{record.product.name}</a>],
        ["Обновлён", dateTime(record.updated_at)],
      ]} />
      <Button secondary href={queryPath(routes.movements, pair)}>История по этому остатку</Button>
    </section>
  </>;
}

function MovementType({ type }) {
  return <span className={"movement-type " + (type === "receipt" ? "receipt" : "issue")}>{movementTypes[type]}</span>;
}

export function Movements({ rows, filters, pagination, products, warehouses }) {
  return <>
    <PageHeading title="Журнал операций" description="Приход и расход в порядке от новых к старым"
      actions={<Button href={queryPath(routes.movements + "/new", filters)}>＋ Новая операция</Button>} />
    <Filters path={routes.movements} filters={filters} searchPlaceholder="Товар, артикул или склад">
      <PairFilters products={products} warehouses={warehouses} filters={filters} />
      <Field label="Тип" name="movement_type" value={filters.movement_type} options={typeOptions} placeholder="Все операции" />
      <Field label="С даты" name="start_date" value={filters.start_date} type="date" />
      <Field label="По дату" name="end_date" value={filters.end_date} type="date" />
    </Filters>
    {rows.length ? <Table label="Журнал операций" headers={["Операция", "Тип", "Товар", "Склад", "Количество", "Автор", "Дата и время"]}
      rows={rows.map(row => ({
        id: row.id, cells: [<a href={routes.movements + "/" + row.id}>№ {row.id}</a>,
          <MovementType type={row.movement_type} />, row.product.name, row.warehouse.name,
          <span className="numeric">{row.movement_type === "receipt" ? "+" : "−"}{amount(row.quantity)} {row.product.unit}</span>,
          row.author, dateTime(row.created_at)],
      }))} /> : <Empty title="Операций не найдено" description="Измените фильтры или оформите новую операцию." />}
    <Pagination path={routes.movements} filters={filters} page={pagination} />
  </>;
}

export function Movement({ record }) {
  const pair = { product_id: record.product.id, warehouse_id: record.warehouse.id };
  const reverse = record.movement_type === "receipt" ? "issue" : "receipt";
  return <>
    <Back href={routes.movements}>Журнал операций</Back>
    <PageHeading title={"Операция № " + record.id} description={dateTime(record.created_at)} />
    <section className="panel">
      <MovementType type={record.movement_type} />
      <div className="stock-number"><strong>{record.movement_type === "receipt" ? "+" : "−"}{amount(record.quantity)} {record.product.unit}</strong></div>
      <DetailList fields={[
        ["Товар", <a href={routes.products + "/" + record.product.id}>{record.product.name} · {record.product.sku}</a>],
        ["Склад", <a href={routes.warehouses + "/" + record.warehouse.id}>{record.warehouse.name}</a>],
        ["Автор", record.author], ["Примечание", record.note],
      ]} />
      <div className="actions">
        <Button secondary href={queryPath(routes.balances, pair)}>Проверить остаток</Button>
        <Button secondary href={queryPath(routes.movements + "/new", { ...pair, movement_type: reverse, quantity: record.quantity })}>Оформить обратную операцию</Button>
      </div>
    </section>
  </>;
}

export function MovementForm({ products, warehouses, values, errors }) {
  return <>
    <Back href={routes.movements}>Журнал операций</Back>
    <PageHeading title="Новая операция" description="Проведение обновит остаток выбранного товара на указанном складе." />
    {!products.length || !warehouses.length ? <Empty title="Заполните справочники" description="Для операции нужен хотя бы один товар и один склад.">
      <div className="actions"><Button href={routes.products + "/new"}>Добавить товар</Button><Button secondary href={routes.warehouses + "/new"}>Добавить склад</Button></div>
    </Empty> : <PostForm action={routes.movements} className="panel form-panel">
      <ErrorSummary errors={errors} />
      <div className="form-fields">
        <Field label="Товар" name="stock_movement[product_id]" options={productOptions(products)} value={values.product_id} errors={errors.product_id} required />
        <Field label="Склад" name="stock_movement[warehouse_id]" options={warehouseOptions(warehouses)} value={values.warehouse_id} errors={errors.warehouse_id} required />
        <Field label="Тип операции" name="stock_movement[movement_type]" options={typeOptions} value={values.movement_type || "receipt"} errors={errors.movement_type} required />
        <Field label="Количество" name="stock_movement[quantity]" inputMode="decimal" placeholder="Например, 3,25" value={values.quantity} errors={errors.quantity} required />
        <Field label="Примечание" name="stock_movement[note]" type="textarea" maxLength={5000} value={values.note} errors={errors.note} />
        <div className="actions"><Button>Провести операцию</Button><Button secondary href={routes.movements}>Отмена</Button></div>
      </div>
    </PostForm>}
  </>;
}
