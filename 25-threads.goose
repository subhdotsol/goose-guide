import std;

// =====================================================================
// 25. Threads
// ---------------------------------------------------------------------
// IMPORTANT: the in-process JIT (`goose file.goose`) CANNOT run threaded
// programs (its TinyCC backend cannot place thread-local storage). Build a
// real executable with a C compiler and run that. From goose-guide:
//
//     ../oss/goose/build/goose build 25-threads.goose -o /tmp/25-threads && /tmp/25-threads
//
// Model: there is NO SHARED MEMORY. Every `thread_fn` (and everything it
// calls) is compiled as a SEPARATE PROGRAM with its own memory and its own
// copies of the globals it uses (copied from the spawner at spawn time).
// So there are no data races, no locks, no atomics, no memory orderings.
// Values travel between threads through TYPED QUEUES — one queue per type —
// and every value that crosses (including worker arguments) must be FLAT:
// no references or slices at any depth.
// =====================================================================

// Message types. Each struct type gets its own queue.
// They are flat: only scalars (an inline u8[..N] string would be flat too).
struct Job { n: i32 }
struct Res { n: i32, sq: i64 }
struct Note { id: i64 }                 // used for the qget-with-timeout / qpoll demo
struct Spam { k: i64 }                  // used for the qlimit demo

// A not-flat message would be rejected: a slice field points into memory the
// receiving program does not have.
//   struct BadMsg { name: u8[:] }      // qput(BadMsg{..}) -> error: not flat

var counter = 0;                        // a global: each worker gets its OWN copy

// ---------------------------------------------------------------------
// A worker: `thread_fn` instead of `fn`
// ---------------------------------------------------------------------
thread_fn worker() {
    loop {
        let job = qget<Job>();                       // blocks until a Job is on the queue
        guard job.n >= 0 else { break; }             // a negative n is our stop signal
        counter += 1;                                // increments THIS worker's copy only
        qput(Res { n: job.n, sq: job.n as i64 * job.n });  // send a result back
    }
}

// A worker with arguments. Arguments must be flat too, and a thread_fn's
// parameters cannot have default values.
thread_fn greeter(id: i64, times: i64) {
    for i in times { qput(Note { id: id * 100 + i }); }
}

// A worker meant for thread_spawn_contained: a failed check or abort ends
// only this worker, and the message goes to whoever waits for it.
thread_fn fragile(attempt: i64) {
    assert(attempt >= 2);                            // the first two attempts "crash"
    qput(Note { id: 1000 + attempt });               // success report
}

fn main() {
    // -----------------------------------------------------------------
    // hardware_threads(): a sensible worker count for this machine
    // -----------------------------------------------------------------
    let hw = hardware_threads();
    print("hardware_threads() >= 1: ", hw >= 1);
    let nworkers = 2;                                // fixed so output is deterministic

    // -----------------------------------------------------------------
    // qput / thread_spawn / qget / thread_wait — the worker-pool pattern
    // -----------------------------------------------------------------
    for i in 4 { qput(Job { n: i as i32 }); }        // queue 4 jobs (messages outlive sender)
    for i in nworkers { qput(Job { n: -1 }); }       // one stop signal per worker
    var ids: i64[>..] = [];
    for i in nworkers { ids.push(thread_spawn(worker)); }   // returns an id (never reused)
    var sum = 0;
    for i in 4 { sum += qget<Res>().sq; }            // blocking receive of 4 results
    for id in ids { thread_wait(id); }               // wait for each worker to end
    print("sum of squares 0..3 = ", sum);            // 0+1+4+9 = 14
    print("main's counter is still ", counter);      // workers changed their own copies

    // -----------------------------------------------------------------
    // thread_spawn(f, args...) — passing arguments
    // -----------------------------------------------------------------
    let g = thread_spawn(greeter, 7, 3);             // greeter(7, 3) in a new thread
    thread_wait(g);                                  // after this, its 3 Notes are queued
    var got = 0;
    for i in 3 { got += qget<Note>().id; }           // 700 + 701 + 702
    print("greeter notes total = ", got);

    // -----------------------------------------------------------------
    // qget<T>(ms): receive with a timeout -> (T, bool)
    // qpoll<T>(): receive without blocking -> (T, bool)
    // On failure you get T's zero value and false.
    // -----------------------------------------------------------------
    let n1, ok1 = qget<Note>(50);                    // queue is empty: waits 50 ms, gives up
    print("qget<Note>(50) on empty queue: ok = ", ok1, ", value id = ", n1.id);
    let n2, ok2 = qpoll<Note>();                     // returns immediately
    print("qpoll<Note>() on empty queue: ok = ", ok2, ", value id = ", n2.id);
    qput(Note { id: 42 });
    let n3, ok3 = qpoll<Note>();                     // now there is one
    print("qpoll<Note>() after qput: ok = ", ok3, ", value id = ", n3.id);

    // -----------------------------------------------------------------
    // qlimit<T>(n): cap a queue. qput then returns false at once when full
    // (it never waits), so a server can turn work away.
    // -----------------------------------------------------------------
    qlimit<Spam>(2);
    let a = qput(Spam { k: 1 });                     // true
    let b = qput(Spam { k: 2 });                     // true
    let c = qput(Spam { k: 3 });                     // false: queue full
    print("qput into qlimit 2 queue: ", a, " ", b, " ", c);
    // `qput(v);` as a statement just ignores that bool.
    let s1, sok1 = qpoll<Spam>();                    // drain it again
    let s2, sok2 = qpoll<Spam>();
    print("drained Spam: ", s1.k, " ", s2.k, " (", sok1 && sok2, ")");

    // -----------------------------------------------------------------
    // thread_spawn_contained + thread_wait(id, msg): a supervisor
    // -----------------------------------------------------------------
    // thread_wait returns false if a CONTAINED worker aborted; the first
    // thread_wait(id, msg) appends its abort message (with source location).
    var attempt = 0;
    var why: u8[>..] = [];
    while !thread_wait(thread_spawn_contained(fragile, attempt), why) {
        print("attempt ", attempt, " failed: ", why);
        why.clear();                                 // later waits give no message
        attempt += 1;
    }
    print("attempt ", attempt, " succeeded, note id = ", qget<Note>().id);

    // -----------------------------------------------------------------
    // Gotchas
    // -----------------------------------------------------------------
    // * An abort in a worker started with plain thread_spawn ends the whole
    //   program. So do stack overflow, exit(code) and aborts on main.
    // * A worker that a contained worker starts with thread_spawn is not
    //   contained.
    // * Workers still running when main returns are killed.
    // * A non-flat global used by anything a thread_fn reaches is an error,
    //   unless it is a `let` whose references lead only to static data.
    print("done");
}
