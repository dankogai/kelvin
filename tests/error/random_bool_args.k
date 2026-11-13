// bool.random() is a coin's toss, and takes nothing (#547)
let main():int32 {
    println(bool.random(1))
    return 0
}
// error: bool.random() takes nothing: it is true or false, each as likely
