import { Back, Button, DetailList, Empty, ErrorSummary, Field, Filters, MaterialIcon, PageHeading, Pagination, PostForm, Table, queryPath, routes } from "./ui";

const catalog = {
  product: {
    path: routes.products, plural: "Товары", create: "Добавить товар", edit: "Редактировать товар",
    search: "Название или артикул", singular: "Товар",
    fields: [
      { key: "name", label: "Наименование", required: true, maxLength: 150 },
      { key: "sku", label: "Артикул", required: true, maxLength: 100, placeholder: "Например, TL-001" },
      { key: "unit", label: "Единица измерения", required: true, maxLength: 30, placeholder: "Например, м²" },
      { key: "description", label: "Описание", type: "textarea", maxLength: 5000 },
    ],
  },
  warehouse: {
    path: routes.warehouses, plural: "Склады", create: "Добавить склад", edit: "Редактировать склад",
    search: "Название склада", singular: "Склад",
    fields: [
      { key: "name", label: "Название", required: true, maxLength: 150 },
      { key: "address", label: "Адрес", maxLength: 255 },
      { key: "description", label: "Описание", type: "textarea", maxLength: 5000 },
    ],
  },
};

const catalogKind = screen => screen.startsWith("warehouse") ? "warehouse" : "product";

export function Catalog({ screen, rows, filters, pagination, icons }) {
  const kind = catalogKind(screen);
  const c = catalog[kind];
  const columns = c.fields.filter(field => field.key !== "description");
  return <>
    <PageHeading title={c.plural} actions={<Button href={c.path + "/new"}>＋ {c.create}</Button>} />
    <Filters path={c.path} filters={filters} searchPlaceholder={c.search} />
    {rows.length ? <Table label={c.plural} headers={columns.map(field => field.label)} rows={rows.map(row => ({
      id: row.id, cells: columns.map(field => field.key === "name"
        ? <a className="row-link" href={c.path + "/" + row.id}>
          {kind === "product" && <MaterialIcon name={row.name} icons={icons} />}{row.name}</a>
        : row[field.key] || "—"),
    }))} /> : <Empty title="Записей нет" description="Измените запрос или добавьте запись в справочник." />}
    <Pagination path={c.path} filters={filters} page={pagination} />
  </>;
}

export function CatalogDetail({ screen, record, icons }) {
  const kind = catalogKind(screen);
  const c = catalog[kind];
  return <>
    <Back href={c.path}>{c.plural}</Back>
    <PageHeading title={record.name} description={c.singular}
      actions={<Button secondary href={c.path + "/" + record.id + "/edit"}>Редактировать</Button>} />
    <section className="panel">
      {kind === "product" && <MaterialIcon name={record.name} icons={icons} />}
      <DetailList fields={c.fields.map(field => [field.label, record[field.key]])} />
      <Button secondary href={queryPath(routes.balances, { [kind + "_id"]: record.id })}>Посмотреть остатки</Button>
    </section>
  </>;
}

export function CatalogForm({ screen, id, values, errors }) {
  const kind = catalogKind(screen);
  const c = catalog[kind];
  const destination = id ? c.path + "/" + id : c.path;
  return <>
    <Back href={destination}>{id ? "К карточке" : c.plural}</Back>
    <PageHeading title={id ? c.edit : c.create} />
    <PostForm action={destination} verb={id ? "patch" : undefined} className="panel form-panel">
      <ErrorSummary errors={errors} />
      <div className="form-fields">
        {c.fields.map(({ key, ...field }) => <Field key={key} {...field} name={kind + "[" + key + "]"}
          value={values[key]} errors={errors[key]} />)}
        <div className="actions"><Button>Сохранить</Button><Button href={destination} secondary>Отмена</Button></div>
      </div>
    </PostForm>
  </>;
}
