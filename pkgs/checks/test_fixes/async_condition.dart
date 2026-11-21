import 'package:checks/checks.dart';

void takeCondition(
  AsyncCondition<int> cond,
  AsyncCondition<String>? nullableCond,
  List<AsyncCondition<int>> nested,
) {}

AsyncCondition<int> castCondition(Object value) => value as AsyncCondition<int>;
