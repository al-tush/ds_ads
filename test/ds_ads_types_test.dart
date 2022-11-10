import 'package:ds_ads/ds_ads.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DSAdLocation', () async {
    const someLocation = DSAdLocation('some_location');
    const someInternalLocation = DSAdLocation('internal_some_location');
    expect('$someLocation', 'some_location');
    expect(someLocation.isInternal, false);
    expect(someInternalLocation.isInternal, true);
  });

}