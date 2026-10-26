// =====================================================================
// geolib/geolib.goose — the ENTRY file of a tiny local package "geolib".
// ---------------------------------------------------------------------
// A package is a directory whose entry module is named after it
// (geolib/geolib.goose). The root program declares it with:
//     import geolib from "./24-modules/geolib";
// Inside the package, `import x;` is resolved relative to the PACKAGE ROOT
// (this directory), and `import .x;` relative to THIS FILE.
// =====================================================================

import std;                 // the standard library is reachable from packages too
import util.strings;        // -> geolib/util/strings.goose (relative to the package root)
import .helpers;            // -> geolib/helpers.goose (relative to this file; leading dot)

// `namespace geolib;` must come at the top, before declarations (imports may
// precede it). Every declaration below lives in the namespace `geolib`, so
// from outside it is written `geolib::Pt`, `geolib::norm1(p)`, ...
// By convention a package's files use the package name as their namespace.
namespace geolib;

// A struct in namespace geolib: its full name is geolib::Pt.
struct Pt { x: i64, y: i64 }

// Manhattan length. `abs` is not declared in geolib, so the unqualified name
// falls through to the GLOBAL namespace and finds std's abs.
fn norm1(p: Pt) -> i64 { abs(p.x) + abs(p.y) }

// A `format` hook for Pt. print(p) finds geolib::format for a geolib::Pt
// from ANY namespace, because the hook follows the value's type.
fn format(out: u8[>..]&, p: Pt) { format(out, "Pt(", p.x, ",", p.y, ")"); }

// A namespaced `describe` that shadows the root program's global `describe`.
// Inside geolib, plain `describe(...)` means THIS one; `::describe(...)`
// reaches the GLOBAL declaration it shadows.
fn describe(n: i64) -> u8[>..] { str("geolib::describe(", n, ")") }

fn shadow_demo() -> u8[>..] {
    // describe(1)   -> geolib's own (current namespace is searched first)
    // ::describe(2) -> the global-namespace describe declared in the root file
    return str(describe(1), " / ", ::describe(2));
}

// A declaration may NAME its namespace itself. `fn ::name` declares into the
// GLOBAL namespace even though this file is `namespace geolib;` — this is how
// `fn ::main()` works in a namespaced root file.
fn ::geolib_banner() -> const u8[:] { "geolib v1 (declared with fn ::geolib_banner)" }

// Uses the two imported modules (which also declare into namespace geolib).
fn label(p: Pt) -> u8[>..] { str(bracket("pt"), " ", twice(p.x)) }
