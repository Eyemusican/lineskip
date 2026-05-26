import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noline_skip/models/hospital.dart';
import 'package:noline_skip/widgets/hospital_card.dart';

Hospital makeHospital({
  String id = 'h1',
  String name = 'Jigme Dorji Wangchuck National Referral Hospital',
  String shortName = 'JDWNRH',
  String location = 'Thimphu',
  int currentQueue = 5,
  int estimatedWaitMinutes = 20,
  String speciality = 'General OPD',
  bool isOpen = true,
}) =>
    Hospital(
      id: id,
      name: name,
      shortName: shortName,
      location: location,
      currentQueue: currentQueue,
      estimatedWaitMinutes: estimatedWaitMinutes,
      speciality: speciality,
      isOpen: isOpen,
    );

Widget buildCard(Hospital hospital, {int activeCount = 5}) => MaterialApp(
      home: Scaffold(
        body: HospitalCard(
          hospital: hospital,
          activeCount: activeCount,
          onBookTap: () {},
        ),
      ),
    );

void main() {
  testWidgets('renders hospital short name and full name', (tester) async {
    await tester.pumpWidget(buildCard(
      makeHospital(shortName: 'JDWNRH', name: 'Jigme Dorji Wangchuck National Referral Hospital'),
    ));

    expect(find.text('JDWNRH'), findsOneWidget);
    expect(find.text('Jigme Dorji Wangchuck National Referral Hospital'), findsOneWidget);
  });

  testWidgets('shows Open badge when hospital is open', (tester) async {
    await tester.pumpWidget(buildCard(makeHospital(isOpen: true)));

    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Closed'), findsNothing);
  });

  testWidgets('shows Closed badge when hospital is closed', (tester) async {
    await tester.pumpWidget(buildCard(makeHospital(isOpen: false)));

    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('Open'), findsNothing);
  });

  testWidgets('displays correct queue count', (tester) async {
    await tester.pumpWidget(buildCard(makeHospital(), activeCount: 7));

    expect(find.text('7 in queue'), findsOneWidget);
  });

  testWidgets('shows Short Wait label for queue <= 10', (tester) async {
    await tester.pumpWidget(buildCard(makeHospital(), activeCount: 8));

    expect(find.text('Short Wait'), findsOneWidget);
  });

  testWidgets('shows Moderate label for queue 11-20', (tester) async {
    await tester.pumpWidget(buildCard(makeHospital(), activeCount: 15));

    expect(find.text('Moderate'), findsOneWidget);
  });

  testWidgets('shows Busy label for queue > 20', (tester) async {
    await tester.pumpWidget(buildCard(makeHospital(), activeCount: 25));

    expect(find.text('Busy'), findsOneWidget);
  });

  testWidgets('Book token button is present when hospital is open', (tester) async {
    await tester.pumpWidget(buildCard(makeHospital(isOpen: true)));

    expect(find.text('Book token'), findsOneWidget);
  });

  testWidgets('renders location text', (tester) async {
    await tester.pumpWidget(buildCard(makeHospital(location: 'Thimphu')));

    expect(find.text('Thimphu'), findsOneWidget);
  });
}
