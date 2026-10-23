// runtime/task.k - Task<T> (#312): async f(x), a call on a thread of its
// own, written in Kelvin (#289): kelvinc --runtime builds it into
// libkelvin, each kv_ function by the name kelvin_prelude.h declares. The
// C kelvinc writes makes the call in a function of its own, from an
// environment that holds its value first and then its arguments; a POSIX
// thread runs it. A Task is an owner: await, or its block's end, joins
// the thread.
#import <pthread.h> as C
#import <stdlib.h> as C
#import <string.h> as C

// the thread, the environment it was given, and what frees the value in
// it, where the value owns, for a Task never awaited
struct job {
    th: pthread_t
    env: any^
    drop: (any^):()
}

// a call's environment: n bytes, zeroed, or the program ends
let kv_task_env(n:size_t):any^ {
    let p:any^ := calloc(1, n)
    if p == nullptr { kv_array_fail("out of memory") }
    return p
}

// async f(x): run(env) starts on a thread of its own, or the program ends
let kv_task_start(run:(any^):any^, env:any^, drop:(any^):()):kv_task {
    let j:job^ := calloc(1, sizeof(job)) as job^
    if j == nullptr { kv_array_fail("out of memory") }
    j^.env := env
    j^.drop := drop
    if pthread_create(&j^.th, nullptr, run, env) != 0 { kv_array_fail("a Task cannot start: no thread") }
    var t:kv_task
    t.job := j
    return t
}

// the thread joined, and its environment given back, the Task emptied
static let joined(t:kv_task^):any^ {
    let j:job^ := t^.job as job^
    if j == nullptr { kv_array_fail("this Task was awaited already, or moved out") }
    pthread_join(j^.th, nullptr)
    let env:any^ := j^.env
    free(j)
    t^.job := nullptr
    return env
}

// await t: the n bytes of the value moved into out, the environment freed
let kv_task_result(t:kv_task^, out:any^, n:size_t) {
    let env:any^ := joined(t)
    if n > 0 { memcpy(out, env, n) }
    free(env)
}

// a Task's end: one never awaited is awaited here, and its value freed
let kv_task_free(t:kv_task^) {
    if t^.job == nullptr { return }
    let drop:(any^):() := (t^.job as job^)^.drop
    let env:any^ := joined(t)
    if drop != nullptr { drop(env) }
    free(env)
}

let kv_task_take(t:kv_task^):kv_task {
    let v:kv_task = t^
    t^.job := nullptr
    return v
}

let kv_task_copy(t:const kv_task^):kv_task {
    kv_array_fail("a Task is not copied: pass it on, or await it")
    return t^
}

// t = async f(x): the old one awaited and freed, the new one kept
let kv_task_assign(t:kv_task^, v:kv_task) {
    kv_task_free(t)
    t^ = v
}

let kv_task_discard(v:kv_task) {
    var t:kv_task = v
    kv_task_free(&t)
}
