# state_store_rc

An utility application that displays the contents of a [StateStore].
Effectively you can run your app for example in a Simulator and have this
app running as a desktop app. And then configure the phone app with
´´´
await StateStore.connectRemoteDebugging();
´´´
and then see the full contents of the [StateStore] in the desktop app in real time.
