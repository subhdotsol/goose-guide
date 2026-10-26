/* 27-calling-c/impl.c — the program's OWN C, used by ../27-calling-c.goose.
   It is compiled because the sidecar ../27-calling-c.build lists it:
       c_sources = ["27-calling-c/impl.c"];
   `goose build` links it into the executable; `goose run` (the default)
   builds it into a shared library that the in-process run loads. */
#include <stdint.h>
#include "goose.h"   /* written by the compiler: gs_rref + gs_bld_append for builders */

/* A Goose slice `T[:]` crosses as a { data, len } struct passed BY VALUE. */
typedef struct { const uint8_t *data; int64_t len; } bytes_view;
typedef struct { const int32_t *data; int64_t len; } i32_view;

/* Must match the Goose struct `Stats { lo: i32, hi: i32, mean: f64 }`.
   Goose uses a PACKED layout; here i32,i32,f64 already sits where C puts it
   (8 bytes then an 8-aligned double), so no `pad` is needed. */
typedef struct { int32_t lo; int32_t hi; double mean; } Stats;

/* extern fn crc32_bytes(s: const u8[:]) -> u32;  — bitwise CRC-32 (IEEE). */
uint32_t crc32_bytes(bytes_view s) {
    uint32_t crc = 0xFFFFFFFFu;
    for (int64_t i = 0; i < s.len; i++) {
        crc ^= s.data[i];
        for (int k = 0; k < 8; k++) crc = (crc >> 1) ^ (0xEDB88320u & (0u - (crc & 1u)));
    }
    return ~crc;
}

/* extern fn fill(out: Stats&);  — a `T&` arrives as a plain pointer. */
void fill(Stats *out) { out->lo = -1; out->hi = 1; out->mean = 0.5; }

/* extern fn stats_of(xs: const i32[:], out: Stats&); */
void stats_of(i32_view xs, Stats *out) {
    if (xs.len == 0) { out->lo = out->hi = 0; out->mean = 0; return; }
    int32_t lo = xs.data[0], hi = xs.data[0];
    double sum = 0;
    for (int64_t i = 0; i < xs.len; i++) {
        if (xs.data[i] < lo) lo = xs.data[i];
        if (xs.data[i] > hi) hi = xs.data[i];
        sum += xs.data[i];
    }
    out->lo = lo; out->hi = hi; out->mean = sum / (double)xs.len;
}

/* extern fn c_version(out: u8[>..]&);  — a builder C APPENDS to. */
void c_version(gs_rref out) {
    static const char msg[] = "impl.c v1.0";
    gs_bld_append(out, msg, (int64_t)(sizeof msg - 1));
}

/* extern fn c_twice(x: i32) -> i32 = "impl_twice";  — a different C name. */
int32_t impl_twice(int32_t x) { return x * 2; }
