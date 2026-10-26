import std;

// =====================================================================
// 30. Operator precedence
//
// From TIGHTEST (binds first) to LOOSEST - the same table as Rust:
//
// | Level          | Operators                                         |
// |----------------|---------------------------------------------------|
// | postfix        | f(...)  a[i]  a[x..y]  .field  x as T  x as! T    |
// | unary          | -  !  ~  &                                        |
// | multiplicative | *  /  %                                           |
// | additive       | +  -                                              |
// | shift          | <<  >>                                            |
// | bitwise and    | &                                                 |
// | bitwise xor    | ^                                                 |
// | bitwise or     | |                                                 |
// | comparison     | <  <=  >  >=                                      |
// | equality       | ==  !=  .==  .!=                                  |
// | logical and    | &&                                                |
// | logical or     | ||                                                |
//
// Binary operators on the same level group LEFT to right.
// BIG difference from C: the bitwise operators & ^ | bind TIGHTER than
// comparisons, so `flags & 2 != 0` means `(flags & 2) != 0`.
//
// - Assignments (=, .=, op=, ++, --) are STATEMENTS, not expressions.
// - A range a..b appears ONLY in slicing brackets, `for` headers and
//   `match` arms.
//
// Each demo below prints the unparenthesized expression next to the two
// possible groupings, so the output PROVES which grouping Goose picks.
// =====================================================================

struct Point { x: i64, y: i64 }

fn double(n: i64) -> i64 { n * 2 }

fn main() {
    // -----------------------------------------------------------------
    // postfix: f(...)  a[i]  a[x..y]  .field  x as T  x as! T
    // Postfix operators bind tightest and chain left to right.
    // -----------------------------------------------------------------
    let xs: i64[5] = [10, 20, 30, 40, 50];
    let p = Point { x: 3, y: 4 };
    // A call binds before the multiplication: (double(3)) * 2
    print("double(3) * 2        = ", double(3) * 2);           // 12
    // Unary minus applies to the WHOLE postfix chain: -(xs[1]), -(p.x), -(double(3))
    print("-xs[1], -p.x, -double(3) = ", -xs[1], ", ", -p.x, ", ", -double(3));
    // Postfix chains: slice first, then .len on the slice, then [i] on the slice
    print("xs[1..4].len         = ", xs[1..4].len);            // 3
    print("xs[1..4][0]          = ", xs[1..4][0]);             // 20
    // `as` is postfix too: it binds tighter than `+`, so it casts only `k`
    let y: i64 = 300;
    let k: i64 = 213;
    print("y + k as! u8         = ", y + k as! u8);            // 300 + 213 = 513
    print("(y + k) as! u8       = ", (y + k) as! u8);          // 513 truncated to u8 = 1
    print("y + k as i32         = ", y + k as i32, "  (k cast, then widened back)");
    // `as` binds tighter than unary minus too:
    // let a: i64 = 6;
    // print(-a as u8);   // error: "cannot negate a value of unsigned type u8"
    //                    // it parses as -(a as u8), NOT (-a) as u8

    // -----------------------------------------------------------------
    // unary: -  !  ~  &   (bind tighter than every binary operator)
    // -----------------------------------------------------------------
    // -7 % 3 is (-7) % 3. % is Euclidean, so (-7) % 3 = 2, while -(7 % 3) = -1
    print("-7 % 3               = ", -7 % 3, "   (-7) % 3 = ", (-7) % 3, "   -(7 % 3) = ", -(7 % 3));
    // ~5 + 1 is (~5) + 1 = -6 + 1 = -5, not ~(5 + 1) = -7
    print("~5 + 1               = ", ~5 + 1, "   (~5) + 1 = ", (~5) + 1, "   ~(5 + 1) = ", ~(5 + 1));
    // !t || t: (!t) || t = true, while !(t || t) = false
    let t = true;
    print("!t || t              = ", !t || t, "   (!t) || t = ", (!t) || t, "   !(t || t) = ", !(t || t));
    // & makes a reference to the whole postfix lvalue: &(ws[1]), not (&ws)[1]
    var ws: i64[3] = [1, 2, 3];
    let r = &ws[1];                     // reference to element 1
    r += 100;                           // write through the reference
    print("&ws[1] then += 100   : ws = ", ws);   // [1, 102, 3]

    // -----------------------------------------------------------------
    // multiplicative (* / %) over additive (+ -)
    // -----------------------------------------------------------------
    print("2 + 3 * 4            = ", 2 + 3 * 4, "   2 + (3 * 4) = ", 2 + (3 * 4), "   (2 + 3) * 4 = ", (2 + 3) * 4);
    print("10 - 6 / 2           = ", 10 - 6 / 2, "    (10 - 6) / 2 = ", (10 - 6) / 2);
    print("7 + 10 % 4           = ", 7 + 10 % 4, "    (7 + 10) % 4 = ", (7 + 10) % 4);
    // Same level -> left to right
    print("20 - 5 - 3           = ", 20 - 5 - 3, "   (20 - 5) - 3 = ", (20 - 5) - 3, "   20 - (5 - 3) = ", 20 - (5 - 3));
    print("100 / 10 / 2         = ", 100 / 10 / 2, "    (100 / 10) / 2 = ", (100 / 10) / 2, "   100 / (10 / 2) = ", 100 / (10 / 2));
    print("2 * 7 % 4            = ", 2 * 7 % 4, "    (2 * 7) % 4 = ", (2 * 7) % 4, "   2 * (7 % 4) = ", 2 * (7 % 4));

    // -----------------------------------------------------------------
    // additive over shift (<< >>)
    // -----------------------------------------------------------------
    print("1 << 2 + 1           = ", 1 << 2 + 1, "    1 << (2 + 1) = ", 1 << (2 + 1), "   (1 << 2) + 1 = ", (1 << 2) + 1);
    print("64 >> 1 + 1          = ", 64 >> 1 + 1, "   64 >> (1 + 1) = ", 64 >> (1 + 1), "   (64 >> 1) + 1 = ", (64 >> 1) + 1);

    // -----------------------------------------------------------------
    // shift over bitwise and (&)
    // -----------------------------------------------------------------
    print("0xF0 & 0x0F << 4     = ", 0xF0 & 0x0F << 4, "  0xF0 & (0x0F << 4) = ", 0xF0 & (0x0F << 4), "   (0xF0 & 0x0F) << 4 = ", (0xF0 & 0x0F) << 4);

    // -----------------------------------------------------------------
    // bitwise and (&) over bitwise xor (^)
    // -----------------------------------------------------------------
    print("6 ^ 3 & 5            = ", 6 ^ 3 & 5, "    6 ^ (3 & 5) = ", 6 ^ (3 & 5), "   (6 ^ 3) & 5 = ", (6 ^ 3) & 5);

    // -----------------------------------------------------------------
    // bitwise xor (^) over bitwise or (|)
    // -----------------------------------------------------------------
    print("1 | 0 ^ 1            = ", 1 | 0 ^ 1, "    1 | (0 ^ 1) = ", 1 | (0 ^ 1), "   (1 | 0) ^ 1 = ", (1 | 0) ^ 1);

    // -----------------------------------------------------------------
    // bitwise or (|) - and every bitwise op - over comparison/equality.
    // This is UNLIKE C, where `flags & 2 != 0` would be `flags & (2 != 0)`.
    // -----------------------------------------------------------------
    var flags: u8 = 0;
    flags |= 1 << 1;                    // compound assignment statement: flags = 2
    let set = flags & 2 != 0;           // (flags & 2) != 0  -> true
    print("flags & 2 != 0       = ", set);
    print("5 & 1 == 1           = ", 5 & 1 == 1, "   (5 & 1) == 1 = ", (5 & 1) == 1);
    print("1 | 2 < 4            = ", 1 | 2 < 4, "   (1 | 2) < 4 = ", (1 | 2) < 4);
    // The other grouping, 1 | (2 < 4), would be int | bool: a type error.

    // -----------------------------------------------------------------
    // comparison (< <= > >=) over equality (== != .== .!=)
    // -----------------------------------------------------------------
    print("1 < 2 == 3 < 4       = ", 1 < 2 == 3 < 4, "   (1 < 2) == (3 < 4) = ", (1 < 2) == (3 < 4));
    print("false == 1 < 2       = ", false == 1 < 2, "  false == (1 < 2) = ", false == (1 < 2));
    print("3 >= 3 != 2 > 5      = ", 3 >= 3 != 2 > 5, "   (3 >= 3) != (2 > 5) = ", (3 >= 3) != (2 > 5));
    // Comparisons do not chain like math: 1 < 2 < 3 is (1 < 2) < 3 = bool < int
    // print(1 < 2 < 3);   // error: "ordering comparison requires numeric operands, got bool and i64"
    //                     // write 1 < 2 && 2 < 3 instead

    // .== / .!= compare references by ADDRESS (same level as == / !=)
    var zs: i64[3] = [7, 7, 7];
    let rz = &zs[2];
    print("rz .== zs[2]         = ", rz .== zs[2], "   (same element)");
    print("rz .== zs[0]         = ", rz .== zs[0], "  (different element...)");
    print("rz == zs[0]          = ", rz == zs[0], "   (...but equal value)");
    print("rz .!= zs[0]         = ", rz .!= zs[0]);

    // -----------------------------------------------------------------
    // equality over logical and (&&)
    // -----------------------------------------------------------------
    print("1 == 1 && 2 == 3     = ", 1 == 1 && 2 == 3, "  (1 == 1) && (2 == 3) = ", (1 == 1) && (2 == 3));
    print("rz .== zs[2] && rz == zs[0] = ", rz .== zs[2] && rz == zs[0]);
    // The other grouping, 1 == (1 && 2) == 3, would be a type error.

    // -----------------------------------------------------------------
    // logical and (&&) over logical or (||). Both short-circuit.
    // -----------------------------------------------------------------
    print("true || false && false = ", true || false && false,
          "   true || (false && false) = ", true || (false && false),
          "   (true || false) && false = ", (true || false) && false);
    // A full chain: postfix, *, +, <, ==, &&, || all at once
    // ((xs[0] + (2 * 5)) > 15) == false || ((p.x < p.y) && !t)
    //   = ((10 + 10 > 15) == false) || (true && false) = (true == false) || false = false
    print("xs[0] + 2 * 5 > 15 == false || p.x < p.y && !t = ",
          xs[0] + 2 * 5 > 15 == false || p.x < p.y && !t);

    // -----------------------------------------------------------------
    // Assignments are STATEMENTS, not expressions - they have no value.
    // -----------------------------------------------------------------
    var n = 1;
    n += 2 * 3;                         // the whole right side first: n = 1 + 6
    n++;                                // ++ is a statement on its own line
    print("n after += 2 * 3 and ++ = ", n);  // 8
    // let m = (n = 5);    // error: "expected ')' in parenthesized expression, found '='"
    // let m = n++;        // error: "expected ';' in variable declaration, found '++'"
    // if (n = 5) { }      // error as well: no assignment inside an expression
    // There is no ternary ?: either - use `if` as an expression:
    let sign = if n > 0 { 1 } else { -1 };
    print("if-expression instead of ?: = ", sign);

    // -----------------------------------------------------------------
    // Ranges a..b appear ONLY in slicing brackets, for headers, match arms.
    // -----------------------------------------------------------------
    print("slice xs[1..3]       = ", xs[1..3]);           // in slicing brackets
    var acc = 0;
    for i in 1..4 { acc += i; }                           // in a for header: 1, 2, 3
    print("sum of for i in 1..4 = ", acc);                // 6
    let grade = match 7 { 0..5 => "low", 5..10 => "mid", _ => "high" };  // in match arms
    print("match 7 on ranges    = ", grade);
    // A range bound can be any expression; `..` is looser than the arithmetic:
    print("xs[1 + 1..2 * 2]     = ", xs[1 + 1..2 * 2]);   // xs[2..4] = [30, 40]
    // let rg = 1..3;      // error: "expected ';' in variable declaration, found '..'"
    //                     // a range is not a value you can store
}
