// todo.mjs — JS/Node OOP tour as a working todo manager
// For a 12-yr Java vet entering JS. Type top-to-bottom, run after each section.
//
// Run from git bash:
//   node todo.mjs                            list all todos
//   node todo.mjs add "buy milk"             add one
//   node todo.mjs done <id>                  mark complete
//   node todo.mjs rm <id>                    remove
//   node todo.mjs serve                      HTTP API on :3000
//   node --test todo.mjs                     run the built-in tests
//
// Convention: every section is self-contained. Type it, save, run, then move on.

// ── imports ─────────────────────────────────────────────────────────────
// java: no 'package' or import-by-classpath. files are modules. the 'node:'
// prefix marks built-ins (vs npm packages, which have no prefix).
import { readFile, writeFile } from 'node:fs/promises';
import { EventEmitter }        from 'node:events';
import { createServer }        from 'node:http';
import { describe, it }        from 'node:test';
import { fileURLToPath }       from 'node:url';
import { randomUUID }          from 'node:crypto';
import { argv, env, exit }     from 'node:process';
import assert                  from 'node:assert/strict';

// ── config ──────────────────────────────────────────────────────────────
// ?? is null/undefined fallback. NOT ||, which would also fire on 0, '', false.
// ?. is optional chaining: a?.b is undefined if a is null/undefined, no throw.
const DATA_FILE = env.TODO_FILE ?? './todos.json';
const PORT      = Number(env.PORT ?? 3000);

// ── error hierarchy ─────────────────────────────────────────────────────
// java: no checked exceptions, no `throws` clause. anything can be thrown.
// by convention, throw subclasses of Error. set .name to the subclass name so
// stack traces and logs identify it correctly.
class AppError extends Error {
  constructor(message, { cause, status = 500 } = {}) {
    super(message);
    this.name   = this.constructor.name;
    this.status = status;
    if (cause) this.cause = cause;            // standard since ES2022
  }
}
class ValidationError extends AppError {
  constructor(message) { super(message, { status: 400 }); }
}
class NotFoundError extends AppError {
  constructor(id) { super(`todo ${id} not found`, { status: 404 }); }
}

// ── mixins: the JS answer to "I want multiple inheritance" ──────────────
// java: closest analog is an interface with default methods, but here you
// literally copy methods onto a target object/prototype. duck typing wins:
// any object that gets these properties IS Timestamped, no `implements` ceremony.
const Timestamped = {
  touch() { this.updatedAt = new Date().toISOString(); return this; }
};
const Loggable = {
  log(tag = 'log') {
    console.log(`[${tag}] ${this.constructor.name}#${this.id}`);
    return this;
  }
};

// ── Entity: base class — owns id and timestamps ─────────────────────────
// java: like an abstract base. # makes a field truly private — enforced by the
// VM, not by convention. it's NOT the _underscore prefix, NOT a closure trick.
class Entity {
  #id;
  constructor(id) {
    this.#id       = id ?? randomUUID();
    this.createdAt = new Date().toISOString();
    this.updatedAt = this.createdAt;
  }
  // getter — called as `e.id`, no parens. setter would be `set id(v) { ... }`.
  get id() { return this.#id; }

  // toJSON is a protocol method. JSON.stringify(obj) calls obj.toJSON() if
  // present and serializes the result instead. java analog: jackson @JsonValue.
  toJSON() {
    return { id: this.id, createdAt: this.createdAt, updatedAt: this.updatedAt };
  }
}
// wire the mixins onto Entity's prototype. every Entity (and subclass instance)
// now responds to touch() and log(). this is the "composition" JS prefers.
Object.assign(Entity.prototype, Timestamped, Loggable);

// ── Todo: the Java-familiar OOP face ────────────────────────────────────
class Todo extends Entity {
  #done = false;                              // private with default value
  #title;                                     // private, no default

  // destructured options-object is the JS answer to method overloading.
  // = {} default makes `new Todo()` not throw on `title` being undefined of undefined.
  constructor({ id, title, done = false } = {}) {
    super(id);                                // java: super(id);
    this.#title = Todo.#validateTitle(title); // call private static
    this.#done  = Boolean(done);              // coerce — JS truthy/falsy is its own thing
  }

  // private static — only callable from inside the class
  static #validateTitle(t) {
    if (typeof t !== 'string' || t.trim() === '')
      throw new ValidationError('title must be a non-empty string');
    return t.trim();
  }

  // static factory: idiomatic "construct from raw data" pattern.
  // dispatches to the right subclass based on shape (duck typing).
  static fromJSON(obj) {
    return obj?.kind === 'recurring' ? new RecurringTodo(obj) : new Todo(obj);
  }

  get title() { return this.#title; }
  set title(v) {                              // `todo.title = 'x'` calls this
    this.#title = Todo.#validateTitle(v);
    this.touch();                             // from the Timestamped mixin
  }
  get done() { return this.#done; }

  // method chaining — `return this` is the idiom. enables `t.complete().log()`.
  complete() { this.#done = true;  this.touch(); return this; }
  reopen()   { this.#done = false; this.touch(); return this; }

  // override toJSON: spread parent's output, then add our own fields.
  // spread on objects is the painless "merge" operator.
  toJSON() {
    return { ...super.toJSON(), title: this.title, done: this.done, kind: 'todo' };
  }
  toString() { return `[${this.done ? 'x' : ' '}] ${this.title}`; }
}

// ── RecurringTodo: polymorphism — override complete() ───────────────────
// java: like overriding a non-final method. all JS methods are "virtual".
class RecurringTodo extends Todo {
  #intervalDays;
  // rest pattern collects remaining options; pass them straight to super.
  constructor({ intervalDays = 1, ...rest } = {}) {
    super(rest);
    this.#intervalDays = intervalDays;
  }
  // override: complete, then schedule a reopen after the interval.
  // .unref() so this pending timer doesn't keep the event loop alive (node-only).
  complete() {
    super.complete();
    setTimeout(() => this.reopen(), this.#intervalDays * 86_400_000).unref();
    return this;
  }
  toJSON() {
    return { ...super.toJSON(), kind: 'recurring', intervalDays: this.#intervalDays };
  }
}

// ── factory function: OOP without `class` (no Java analog) ──────────────
// closures hold the private state. the function returns a plain object literal
// whose methods see the captured locals. very common in JS, especially in
// functional-leaning codebases. pros: no `this` traps, real privacy without #,
// trivially composable. cons: no inheritance, no instanceof, more memory per instance.
function makeTodo({ title, done = false } = {}) {
  // these locals ARE the private fields — only the returned methods see them.
  let _title = title;
  let _done  = Boolean(done);
  const id   = randomUUID();
  return {
    id,                                       // shorthand: same as `id: id`
    get title() { return _title; },
    get done()  { return _done; },
    complete()  { _done  = true;       return this; },
    rename(t)   { _title = String(t);  return this; },
    toJSON()    { return { id, title: _title, done: _done, kind: 'factory' }; }
  };
}

// ── prototype peek: what classes desugar to ─────────────────────────────
// every object has a prototype. method lookup walks the chain: own → proto → ...
// classes are sugar; this is the underlying mechanism. read once, then forget.
const protoDemo = Object.create({ hello() { return 'world'; } });
// protoDemo has no own 'hello', but inherits it via its prototype.
//   protoDemo.hello()                        // → 'world'
//   Object.getPrototypeOf(protoDemo).hello   // → the function
//   Object.hasOwn(protoDemo, 'hello')        // → false

// ── TodoCollection: a custom iterable (implements Symbol.iterator) ──────
// java: like implementing Iterable<Todo>. for...of works on anything with a
// [Symbol.iterator]() method. spreading [...coll] uses the same protocol.
class TodoCollection {
  #items = new Map();                         // Map preserves insertion order

  add(todo)   { this.#items.set(todo.id, todo); return this; }
  remove(id)  { if (!this.#items.delete(id)) throw new NotFoundError(id); return this; }
  find(id)    { const t = this.#items.get(id); if (!t) throw new NotFoundError(id); return t; }
  has(id)     { return this.#items.has(id); }
  get size()  { return this.#items.size; }
  filter(fn)  { return [...this].filter(fn); }  // [...this] triggers our iterator

  // generator method — yields one value at a time, IS an iterator.
  *[Symbol.iterator]() {
    for (const t of this.#items.values()) yield t;
  }
  toJSON() { return [...this]; }
}

// ── TodoStore: composition with EventEmitter (has-a, not is-a) ──────────
// alternative: `class TodoStore extends EventEmitter` — works, but exposes
// every EE method on the public API. composition keeps the surface deliberate
// and lets you swap the event bus implementation without breaking callers.
class TodoStore {
  #items = new TodoCollection();
  #bus   = new EventEmitter();

  on(event, fn)  { this.#bus.on(event, fn);  return this; }
  off(event, fn) { this.#bus.off(event, fn); return this; }

  add(input) {
    // duck typing: accept a Todo instance OR a plain object with the shape
    const t = input instanceof Todo ? input : Todo.fromJSON(input);
    this.#items.add(t);
    this.#bus.emit('todo:created', t);
    return t;
  }
  complete(id) {
    const t = this.#items.find(id).complete();
    this.#bus.emit('todo:completed', t);
    return t;
  }
  remove(id) { this.#items.remove(id); this.#bus.emit('todo:removed', id); }
  find(id)   { return this.#items.find(id); }
  list({ done } = {}) {
    return done === undefined
      ? [...this.#items]
      : this.#items.filter(t => t.done === done);
  }
  toJSON() { return this.#items.toJSON(); }

  // async I/O. try/catch around an awaited call is the standard error pattern.
  // java: similar to try { future.get() } catch (ExecutionException e) { ... }
  async load(file = DATA_FILE) {
    try {
      const raw = await readFile(file, 'utf8');
      for (const obj of JSON.parse(raw)) this.#items.add(Todo.fromJSON(obj));
    } catch (err) {
      // ENOENT = file doesn't exist yet (first run). anything else is real.
      if (err.code !== 'ENOENT') throw new AppError('failed to load', { cause: err });
    }
    return this;                              // chainable
  }
  async save(file = DATA_FILE) {
    // JSON.stringify(this) walks the toJSON() chain all the way down.
    await writeFile(file, JSON.stringify(this, null, 2), 'utf8');
  }
}

// ── `this` trap demo: type this section, then read the comments ─────────
// java: a method reference (Counter::inc) is bound to the instance. JS methods
// are NOT — extracting a method drops `this`. three idiomatic fixes below.
class Counter {
  #n = 0;
  inc()    { this.#n += 1; return this.#n; }          // breaks when extracted
  incArr = () => { this.#n += 1; return this.#n; };   // arrow class field: `this` bound at construction
}
function demoThisTrap() {
  const c = new Counter();
  // 1) BROKEN — detach the method, `this` becomes undefined in strict mode:
  //    const f = c.inc; f();                          // TypeError: cannot read #n on undefined
  // 2) FIX with .bind(c) — explicit binding, the Java-instinct fix:
  const g = c.inc.bind(c);  g();
  // 3) FIX with arrow class field — no bind needed, popular in React handlers:
  const h = c.incArr;       h();
  return c;
}

// ── CLI ─────────────────────────────────────────────────────────────────
async function runCli(args) {
  const [cmd, ...rest] = args;                // array destructure: head + tail
  const store = await new TodoStore().load();
  store.on('todo:created',   t  => console.log(`+ ${t.id}  ${t.title}`));
  store.on('todo:completed', t  => console.log(`done ${t.id}`));
  store.on('todo:removed',   id => console.log(`- ${id}`));

  switch (cmd) {
    case 'add': {                             // braces give each case its own block scope
      if (rest.length === 0) throw new ValidationError('usage: add <title...>');
      store.add({ title: rest.join(' ') });
      break;
    }
    case 'done': {
      const [id] = rest;
      if (!id) throw new ValidationError('usage: done <id>');
      store.complete(id);
      break;
    }
    case 'rm': {
      const [id] = rest;
      if (!id) throw new ValidationError('usage: rm <id>');
      store.remove(id);
      break;
    }
    case 'list':
    case undefined: {                          // fall-through case label
      for (const t of store.list()) console.log(`${t.id}  ${t}`);
      return;                                  // no save needed for a read
    }
    case 'serve':
      return runServer(store);                 // never returns — server holds the loop

    default:
      throw new ValidationError(`unknown command: ${cmd}`);
  }
  await store.save();
}

// ── HTTP server (native node:http, no Express) ──────────────────────────
function runServer(store) {
  // helpers in the outer scope, captured by the route handlers below.
  const ok       = (body, status = 200) => ({ status, body });
  const notFound = (target) => { throw new NotFoundError(target); };

  // tuple-style routes: [method, urlPattern, handler(match, body) -> {status, body}]
  const routes = [
    ['GET',    /^\/todos$/,                    ()         => ok(store.list())],
    ['POST',   /^\/todos$/,                    (_m, body) => ok(store.add(body), 201)],
    ['GET',    /^\/todos\/([^/]+)$/,           ([, id])   => ok(store.find(id))],
    ['DELETE', /^\/todos\/([^/]+)$/,           ([, id])   => { store.remove(id); return ok(null, 204); }],
    ['POST',   /^\/todos\/([^/]+)\/complete$/, ([, id])   => ok(store.complete(id))],
  ];

  const server = createServer(async (req, res) => {
    try {
      const body = await readJson(req);
      for (const [method, pattern, handler] of routes) {
        if (req.method !== method) continue;
        const match = pattern.exec(req.url);
        if (!match) continue;
        const { status, body: out } = handler(match, body);
        res.writeHead(status, { 'content-type': 'application/json' });
        return res.end(out === null ? '' : JSON.stringify(out));
      }
      notFound(req.url);                       // no route matched
    } catch (err) {
      const status = err instanceof AppError ? err.status : 500;
      res.writeHead(status, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ error: err.message, name: err.name }));
    } finally {
      // best-effort persistence after every request that might have mutated state
      store.save().catch(e => console.error('save failed:', e.message));
    }
  });

  server.listen(PORT, () => console.log(`listening on http://localhost:${PORT}`));
  // try from another terminal:
  //   curl localhost:3000/todos
  //   curl -X POST localhost:3000/todos -d '{"title":"buy milk"}' -H 'content-type: application/json'
  return new Promise(() => {});                // keep the process alive
}

// stream-style body reader. Buffer.concat joins chunks; UTF-8 decode → JSON.parse.
// returning a Promise from event-based APIs is the classic "promisify" pattern.
function readJson(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data',  c => chunks.push(c));
    req.on('end',   () => {
      const raw = Buffer.concat(chunks).toString('utf8');
      if (!raw) return resolve({});
      try { resolve(JSON.parse(raw)); }
      catch { reject(new ValidationError('invalid json body')); }
    });
    req.on('error', reject);
  });
}

// ── tests (run: node --test todo.mjs) ───────────────────────────────────
// java: like JUnit, but built into node — no install. assert.* throws on fail.
describe('Todo', () => {
  it('rejects empty/whitespace/missing title', () => {
    assert.throws(() => new Todo({ title: '' }),    ValidationError);
    assert.throws(() => new Todo({ title: '   ' }), ValidationError);
    assert.throws(() => new Todo({}),               ValidationError);
  });
  it('trims title on construction', () => {
    const t = new Todo({ title: '  hello  ' });
    assert.equal(t.title, 'hello');
  });
  it('completes and reopens, chainably', () => {
    const t = new Todo({ title: 'x' });
    assert.equal(t.done, false);
    t.complete();
    assert.equal(t.done, true);
    t.reopen();
    assert.equal(t.done, false);
  });
  it('serializes via JSON.stringify (toJSON chain)', () => {
    const t = new Todo({ title: 'x' });
    const json = JSON.parse(JSON.stringify(t));
    assert.equal(json.title, 'x');
    assert.equal(json.kind, 'todo');
    assert.ok(json.id);
    assert.ok(json.createdAt);
  });
  it('setter triggers validation and touch', () => {
    const t = new Todo({ title: 'x' });
    const before = t.updatedAt;
    t.title = 'y';
    assert.equal(t.title, 'y');
    assert.notEqual(t.updatedAt, before);
    assert.throws(() => { t.title = ''; }, ValidationError);
  });
});
describe('TodoStore', () => {
  it('emits todo:created on add', () => {
    const s = new TodoStore();
    let created = 0;
    s.on('todo:created', () => created++);
    s.add({ title: 'a' });
    assert.equal(created, 1);
  });
  it('filters by done flag', () => {
    const s = new TodoStore();
    const a = s.add({ title: 'a' });
    s.add({ title: 'b' });
    s.complete(a.id);
    assert.equal(s.list({ done: true  }).length, 1);
    assert.equal(s.list({ done: false }).length, 1);
    assert.equal(s.list().length, 2);
  });
});
describe('factory todo', () => {
  it('has private state via closures, not # fields', () => {
    const t = makeTodo({ title: 'x' });
    t.rename('y').complete();
    assert.equal(t.title, 'y');
    assert.equal(t.done,  true);
    // no _title leaked as an own property — closure really is private
    assert.equal(Object.hasOwn(t, '_title'), false);
  });
});

// ── entry point ─────────────────────────────────────────────────────────
// java: equivalent of `public static void main`. only run when this file is
// the program entry, not when imported by --test or another file.
// process.execArgv carries the flags BEFORE the script (e.g. --test).
const isDirectRun = argv[1] === fileURLToPath(import.meta.url);
const isTestMode  = process.execArgv.includes('--test');
if (isDirectRun && !isTestMode) {
  try {
    await runCli(argv.slice(2));               // top-level await — module-level, no IIFE
  } catch (err) {
    console.error(`error: ${err.message}`);
    exit(err instanceof AppError ? 1 : 2);
  }
}
