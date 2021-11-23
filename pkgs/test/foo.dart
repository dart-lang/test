import 'dart:isolate';

void main() async {
  print('Start');
  var onExitPort = ReceivePort();
  try {
    await Isolate.spawnUri(Uri.dataFromString(''), [], null,
        onExit: onExitPort.sendPort);
  } on IsolateSpawnException {
    onExitPort.close();
    // nothing
  }
  await onExitPort.first;
}
