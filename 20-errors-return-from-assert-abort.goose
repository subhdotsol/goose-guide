import std;
import exception;          // library module providing try/throw, built on `return ... from`

// ===================================================================
// 20. Errors: return … from, assert, abort
// ===================================================================
// Goose has no Result type, no `?` operator and no built-in exceptions.
// Instead:
//   * `return E from f`  — non-local return to the innermost active call of f
//   * the `exception` library module — try/throw built on top of that
//   * assert / abort / exit — stop the whole program (cannot be caught)

// ---------------------------------------------------------------
// `return E from f`
// ---------------------------------------------------------------
// `return E from f` returns E as the result of the innermost ACTIVE call
// of `f`, however many frames up that call is. Every frame in between
// is exited. It is checked STATICALLY: the compiler proves that every
// call path to the `return ... from load` is inside a call of `load`,
// and that E matches load's result type.

struct User { name: u8[..16], age: i32 }   // u8[..16]: inline string of up to 16 bytes

// `load` returns two results: the users, and an error message
// ("" means success). This is the function that `return ... from` targets.
fn load(text: u8[:]) -> User[>..], u8[] {
    var users: User[>..] = [];                         // the result being built
    each_split(text, '\n') { users.push(parse_user(it)); };  // a block per line
    return users, "";                                  // the success path
}

// A PLAIN signature: it returns a User, not "User or error". On a bad
// line it jumps straight out of `load` (through each_split and the block)
// with load's two results: an empty user list and an error message.
fn parse_user(line: u8[:]) -> User {
    let comma = find(line, ",");                       // index of ',' or -1
    guard comma >= 0 else { return [], str("expected name,age: ", line) from load; }
    let age, ok = parse_int(trim(line[comma + 1..]));  // two results: value and success (trim drops spaces)
    guard ok else { return [], str("bad age: ", line) from load; }
    return User { name: trim(line[..comma]), age: age as i32 };   // normal return
}

// ---------------------------------------------------------------
// Exceptions from the `exception` library module
// ---------------------------------------------------------------
// exception::throw(v) is just `return [v] from exception::handler`, so it
// is also checked statically: every path to a throw must be inside an
// exception::try with a compatible error type.
fn risky(n: i64) {
    if n > 40 { exception::throw(str("bad item ", n)); }  // throws a u8[] error
    print("  risky(", n, ") finished normally");
}

// A deeper call chain: throw unwinds all of these frames.
fn middle(n: i64) { risky(n); print("  middle(", n, ") finished normally"); }

fn main() {
    // ---------------------------------------------------------------
    // return ... from: success and both error paths
    // ---------------------------------------------------------------
    let users, err = load("ada, 36\nlinus, 54");       // all lines OK
    print("ok load: err = \"", err, "\", count = ", users.len);
    for u in users { print("  user ", u.name, " age ", u.age); }

    let u2, err2 = load("ada, 36\nno comma here");    // 2nd line has no comma
    print("bad load: users = ", u2.len, ", err = ", err2);

    let u3, err3 = load("bob, forty");                 // age isn't a number
    print("bad load: users = ", u3.len, ", err = ", err3);

    // parse_user("x,1");
    //   ERROR (static check): calling parse_user here, outside any call of
    //   `load`, would leave `return ... from load` with no target.

    // ---------------------------------------------------------------
    // exception::try / exception::throw
    // ---------------------------------------------------------------
    // try<E>(body) { e => handler }: E is the error type; the body is a
    // named function (passed by name), the catch block is the trailing block.
    // A named function taking no parameters is needed as the body, so we use
    // nested functions that call risky/middle with fixed arguments.
    fn ok_case() { middle(7); }
    fn bad_case() { middle(42); }
    print("try ok_case:");
    exception::try<u8[]>(ok_case) { e => print("  caught ", e); };   // nothing thrown
    print("try bad_case:");
    exception::try<u8[]>(bad_case) { e => print("  caught ", e); };  // 'middle ... finished' is skipped
    // A try with no catch block simply discards the error:
    exception::try<u8[]>(bad_case);
    print("discarded an error silently");

    // ---------------------------------------------------------------
    // assert: abort unless true; also NARROWS an optional
    // ---------------------------------------------------------------
    let x = 5;
    assert(x > 0);                          // true: execution continues
    print("assert(x > 0) passed");

    var answer = 42;                        // a plain local
    let maybe: i64? = answer;               // optionals are nullable REFERENCES: this refers to `answer`
    assert(maybe);                          // abort if null; afterwards `maybe` is narrowed to i64
    print("narrowed by assert: ", maybe + 1);   // usable as a plain i64 now

    // assert(x < 0);
    //   Would ABORT the program here (cannot be caught). Left commented
    //   out so this file runs to completion.

    // ---------------------------------------------------------------
    // abort and exit: stop the program (neither can be caught)
    // ---------------------------------------------------------------
    // abort("message") prints the message and aborts; it never returns,
    // so it can be used where a value is expected in a branch not taken:
    let half = if x % 2 == 1 { x / 2 } else { abort("x must be odd") };
    print("half = ", half, " (the abort branch was not taken)");

    // abort("fatal");   // would end the program immediately with this message
    // exit(1);          // would end the program with exit code 1 (no message)
    print("done");
}
