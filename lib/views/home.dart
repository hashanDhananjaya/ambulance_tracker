import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_webservice/places.dart';
// import 'package:ambulance_tracker/views/my_profile.dart';

import '../controller/auth_controller.dart';
import '../controller/polyline_handler.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import 'package:geocoding/geocoding.dart' as geoCoding;
import 'dart:ui' as ui;

import '../widgets/text_widget.dart';
import 'my_profile.dart';
import 'payment.dart';

enum PatientCondition {
  roadAccident,
  covid,
  heartAttack,
  boneInjury,
  poisoning,
  pregnancy,
  other
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _mapStyle;

  // final Completer<GoogleMapController> _controller = Completer();
  AuthController authController = Get.find<AuthController>();

  late LatLng destination;
  late LatLng source;
  final Set<Polyline> _polyline = {};
  Set<Marker> markers = <Marker>{};
  List<String> list = <String>[
    '**** **** **** 8789',
    '**** **** **** 8921',
    '**** **** **** 1233',
    '**** **** **** 4352'
  ];

  @override
  void initState() {
    super.initState();

    authController.getUserInfo();

    rootBundle.loadString('assets/map_style.txt').then((string) {
      _mapStyle = string;
    });

    loadCustomMarker();
    loadCurrentLocationMarker();
  }

  String dropdownValue = '**** **** **** 8789';
  final CameraPosition _kGooglePlex = const CameraPosition(
    target: LatLng(8.35, 80.7718),
    zoom: 7.75,
  );

  // Future<Position> getUserCurrentLocation() async {
  //   await Geolocator.requestPermission()
  //       .then((value) {})
  //       .onError((error, stackTrace) async {
  //     await Geolocator.requestPermission();
  //     print("ERROR : $error");
  //   });
  //   return await Geolocator.getCurrentPosition();
  // }

  // final List<Marker> _markers = <Marker>[
  //   const Marker(
  //       markerId: MarkerId('1'),
  //       position: LatLng(20.42796133580664, 75.885749655962),
  //       infoWindow: InfoWindow(
  //         title: 'My Position',
  //       )),
  // ];

  GoogleMapController? myMapController;
  PatientCondition? _condition = PatientCondition.covid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildDrawer(),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: GoogleMap(
              mapType: MapType.normal,
              markers: markers,
              polylines: polyline,
              zoomControlsEnabled: false,
              onMapCreated: (GoogleMapController controller) {
                myMapController = controller;

                myMapController!.setMapStyle(_mapStyle);
              },
              initialCameraPosition: _kGooglePlex,
            ),
          ),
          buildProfileTile(),
          buildTextField(),
          showSourceField ? buildTextFieldForSource() : Container(),
          buildCurrentLocationIcon(),
          buildNotificationIcon(),
          buildBottomSheet(),
        ],
      ),
    );
  }

  Widget buildProfileTile() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Obx(() => authController.myUser.value.name == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Container(
              width: Get.width,
              height: Get.width * 0.5,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: const BoxDecoration(color: Colors.white70),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: authController.myUser.value.image == null
                            ? const DecorationImage(
                                image: AssetImage('assets/person.png'),
                                fit: BoxFit.fill)
                            : DecorationImage(
                                image: NetworkImage(
                                    authController.myUser.value.image!),
                                fit: BoxFit.fill)),
                  ),
                  const SizedBox(
                    width: 15,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RichText(
                        text: TextSpan(children: [
                          const TextSpan(
                              text: 'Good Day, ',
                              style:
                                  TextStyle(color: Colors.black, fontSize: 14)),
                          TextSpan(
                              text: authController.myUser.value.name,
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      const Text(
                        "Where are you going?",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      )
                    ],
                  )
                ],
              ),
            )),
    );
  }

  TextEditingController destinationController = TextEditingController();
  TextEditingController sourceController = TextEditingController();

  bool showSourceField = false;

  Widget buildTextField() {
    return Positioned(
      top: 170,
      left: 20,
      right: 20,
      child: Container(
        width: Get.width,
        height: 50,
        padding: const EdgeInsets.only(left: 15),
        decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 4,
                  blurRadius: 10)
            ],
            borderRadius: BorderRadius.circular(8)),
        child: TextFormField(
          controller: destinationController,
          readOnly: true,
          onTap: () async {
            Prediction? p =
                await authController.showGoogleAutoComplete(context);

            String selectedPlace = p!.description!;

            destinationController.text = selectedPlace;

            List<geoCoding.Location> locations =
                await geoCoding.locationFromAddress(selectedPlace);

            destination =
                LatLng(locations.first.latitude, locations.first.longitude);

            markers.add(Marker(
              markerId: MarkerId(selectedPlace),
              infoWindow: InfoWindow(
                title: 'Destination: $selectedPlace',
              ),
              position: destination,
              icon: BitmapDescriptor.fromBytes(markIcons),
            ));

            myMapController!.animateCamera(CameraUpdate.newCameraPosition(
                CameraPosition(target: destination, zoom: 14)
                //17 is new zoom level
                ));

            setState(() {
              showSourceField = true;
            });
          },
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: 'Search for a destination',
            hintStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            suffixIcon: const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(
                Icons.search,
              ),
            ),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget buildTextFieldForSource() {
    return Positioned(
      top: 230,
      left: 20,
      right: 20,
      child: Container(
        width: Get.width,
        height: 50,
        padding: const EdgeInsets.only(left: 15),
        decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 4,
                  blurRadius: 10)
            ],
            borderRadius: BorderRadius.circular(8)),
        child: TextFormField(
          controller: sourceController,
          readOnly: true,
          onTap: () async {
            buildSourceSheet();
          },
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: 'From:',
            hintStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            suffixIcon: const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(
                Icons.search,
              ),
            ),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget buildCurrentLocationIcon() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 30, right: 8),
        child: GestureDetector(
          onTap: () async {
            Position position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high);

            destination = LatLng(position.latitude, position.longitude);

            markers.add(Marker(
              markerId: MarkerId(
                  "Longitude : ${position.longitude}, Latitude : ${position.latitude}"),
              infoWindow: InfoWindow(
                title:
                    'Destination = Longitude : ${position.longitude}, Latitude : ${position.latitude}',
              ),
              position: destination,
              icon: BitmapDescriptor.fromBytes(currentLocationMarker),
            ));

            myMapController!.animateCamera(CameraUpdate.newCameraPosition(
                CameraPosition(target: destination, zoom: 17)
                //17 is new zoom level
                ));

            setState(() {
              showSourceField = true;
            });
          },
          child: const CircleAvatar(
            radius: 20,
            backgroundColor: Colors.red,
            child: Icon(
              Icons.my_location,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildNotificationIcon() {
    return const Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 30, left: 8),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.white,
          child: Icon(
            Icons.notifications,
            color: Color(0xffC3CDD6),
          ),
        ),
      ),
    );
  }

  Widget buildBottomSheet() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: Get.width * 0.8,
        height: 25,
        decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 4,
                  blurRadius: 10)
            ],
            borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12), topLeft: Radius.circular(12))),
        child: Center(
          child: Container(
            width: Get.width * 0.6,
            height: 4,
            color: Colors.black45,
          ),
        ),
      ),
    );
  }

  buildDrawerItem(
      {required String title,
      required Function onPressed,
      Color color = Colors.black,
      double fontSize = 20,
      FontWeight fontWeight = FontWeight.w700,
      double height = 45,
      bool isVisible = false}) {
    return SizedBox(
      height: height,
      child: ListTile(
        contentPadding: const EdgeInsets.all(0),
        // minVerticalPadding: 0,
        dense: true,
        onTap: () => onPressed(),
        title: Row(
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                  fontSize: fontSize, fontWeight: fontWeight, color: color),
            ),
            const SizedBox(
              width: 5,
            ),
            isVisible
                ? CircleAvatar(
                    backgroundColor: AppColors.greenColor,
                    radius: 15,
                    child: Text(
                      '1',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  )
                : Container()
          ],
        ),
      ),
    );
  }

  buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          InkWell(
            onTap: () {
              // Get.to(() => const MyProfile());
            },
            child: SizedBox(
              height: 150,
              child: DrawerHeader(
                  child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: authController.myUser.value.image == null
                            ? const DecorationImage(
                                image: AssetImage('assets/person.png'),
                                fit: BoxFit.fill)
                            : DecorationImage(
                                image: NetworkImage(
                                    authController.myUser.value.image!),
                                fit: BoxFit.fill)),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Good Morning, ',
                            style: GoogleFonts.poppins(
                                color: Colors.black.withOpacity(0.28),
                                fontSize: 14)),
                        Text(
                          authController.myUser.value.name == null
                              ? "Mark"
                              : authController.myUser.value.name!,
                          style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        )
                      ],
                    ),
                  )
                ],
              )),
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                buildDrawerItem(
                    title: 'Payment History',
                    onPressed: () => Get.to(() => PaymentScreen())),
                buildDrawerItem(
                    title: 'Ride History', onPressed: () {}, isVisible: true),
                buildDrawerItem(title: 'Invite Friends', onPressed: () {}),
                buildDrawerItem(title: 'Promo Codes', onPressed: () {}),
                buildDrawerItem(title: 'Settings', onPressed: () {}),
                buildDrawerItem(title: 'Support', onPressed: () {}),
                buildDrawerItem(
                    title: 'Log Out',
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                    }),
              ],
            ),
          ),
          const Spacer(),
          const Divider(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
            child: Column(
              children: [
                buildDrawerItem(
                    title: 'Do more',
                    onPressed: () {},
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black.withOpacity(0.15),
                    height: 20),
                const SizedBox(
                  height: 20,
                ),
                buildDrawerItem(
                    title: 'Get food delivery',
                    onPressed: () {},
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.15),
                    height: 20),
                buildDrawerItem(
                    title: 'Make money driving',
                    onPressed: () {},
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.15),
                    height: 20),
                buildDrawerItem(
                  title: 'Rate us on store',
                  onPressed: () {},
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.15),
                  height: 20,
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 20,
          ),
        ],
      ),
    );
  }

  late Uint8List markIcons;
  late Uint8List currentLocationMarker;

  loadCustomMarker() async {
    markIcons = await loadAsset('assets/dest_marker.png', 100);
  }

  loadCurrentLocationMarker() async {
    currentLocationMarker = await loadAsset('assets/location-pin.png', 100);
  }

  Future<Uint8List> loadAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetHeight: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  void drawPolyline(String placeId) {
    _polyline.clear();
    _polyline.add(Polyline(
      polylineId: PolylineId(placeId),
      visible: true,
      points: [source, destination],
      color: AppColors.greenColor,
      width: 5,
    ));
  }

  void buildSourceSheet() {
    Get.bottomSheet(Container(
      width: Get.width,
      height: Get.height * 0.5,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8), topRight: Radius.circular(8)),
          color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(
            height: 10,
          ),
          const Text(
            "Select Your Location",
            style: TextStyle(
                color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(
            height: 20,
          ),
          // const Text(
          //   "Home Address",
          //   style: TextStyle(
          //       color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
          // ),
          // const SizedBox(
          //   height: 10,
          // ),
          // InkWell(
          //   onTap: () async {
          //     Get.back();
          //     source = authController.myUser.value.homeAddress!;
          //     sourceController.text = authController.myUser.value.hAddress!;
          //
          //     if (markers.length >= 2) {
          //       markers.remove(markers.last);
          //     }
          //     markers.add(Marker(
          //         markerId: MarkerId(authController.myUser.value.hAddress!),
          //         infoWindow: InfoWindow(
          //           title: 'Source: ${authController.myUser.value.hAddress!}',
          //         ),
          //         position: source));
          //
          //     await getPolylines(source, destination);
          //
          //     // drawPolyline(place);
          //
          //     myMapController!.animateCamera(CameraUpdate.newCameraPosition(
          //         CameraPosition(target: source, zoom: 14)));
          //     setState(() {});
          //
          //     buildRideConfirmationSheet();
          //   },
          //   child: Container(
          //     width: Get.width,
          //     height: 50,
          //     padding: const EdgeInsets.symmetric(horizontal: 10),
          //     decoration: BoxDecoration(
          //         color: Colors.white,
          //         borderRadius: BorderRadius.circular(8),
          //         boxShadow: [
          //           BoxShadow(
          //               color: Colors.black.withOpacity(0.04),
          //               spreadRadius: 4,
          //               blurRadius: 10)
          //         ]),
          //     child: Row(
          //       children: [
          //         Text(
          //           authController.myUser.value.hAddress!,
          //           style: const TextStyle(
          //               color: Colors.black,
          //               fontSize: 12,
          //               fontWeight: FontWeight.w600),
          //           textAlign: TextAlign.start,
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
          // const SizedBox(
          //   height: 20,
          // ),
          // const Text(
          //   "Business Address",
          //   style: TextStyle(
          //       color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
          // ),
          // const SizedBox(
          //   height: 10,
          // ),
          // InkWell(
          //   onTap: () async {
          //     Get.back();
          //     source = authController.myUser.value.bussinessAddres!;
          //     sourceController.text = authController.myUser.value.bAddress!;
          //
          //     if (markers.length >= 2) {
          //       markers.remove(markers.last);
          //     }
          //     markers.add(Marker(
          //         markerId: MarkerId(authController.myUser.value.bAddress!),
          //         infoWindow: InfoWindow(
          //           title: 'Source: ${authController.myUser.value.bAddress!}',
          //         ),
          //         position: source));
          //
          //     await getPolylines(source, destination);
          //
          //     // drawPolyline(place);
          //
          //     myMapController!.animateCamera(CameraUpdate.newCameraPosition(
          //         CameraPosition(target: source, zoom: 14)));
          //     setState(() {});
          //
          //     buildRideConfirmationSheet();
          //   },
          //   child: Container(
          //     width: Get.width,
          //     height: 50,
          //     padding: const EdgeInsets.symmetric(horizontal: 10),
          //     decoration: BoxDecoration(
          //         color: Colors.white,
          //         borderRadius: BorderRadius.circular(8),
          //         boxShadow: [
          //           BoxShadow(
          //               color: Colors.black.withOpacity(0.04),
          //               spreadRadius: 4,
          //               blurRadius: 10)
          //         ]),
          //     child: Row(
          //       children: const [
          //         Text(
          //           // authController.myUser.value.bAddress!,
          //           "Galle",
          //           style: TextStyle(
          //               color: Colors.black,
          //               fontSize: 12,
          //               fontWeight: FontWeight.w600),
          //           textAlign: TextAlign.start,
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
          const SizedBox(
            height: 20,
          ),
          InkWell(
            onTap: () async {
              Get.back();
              Prediction? p =
                  await authController.showGoogleAutoComplete(context);

              String place = p!.description!;

              sourceController.text = place;

              source = await authController.buildLatLngFromAddress(place);

              if (markers.length >= 2) {
                markers.remove(markers.last);
              }
              markers.add(Marker(
                  markerId: MarkerId(place),
                  infoWindow: InfoWindow(
                    title: 'Source: $place',
                  ),
                  position: source));

              await getPolylines(source, destination);

              // drawPolyline(place);

              myMapController!.animateCamera(CameraUpdate.newCameraPosition(
                  CameraPosition(target: source, zoom: 14)));
              setState(() {});
              buildRideConfirmationSheet();
            },
            child: Container(
              width: Get.width,
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        spreadRadius: 4,
                        blurRadius: 10)
                  ]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    "Search for Address",
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.start,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }

  buildRideConfirmationSheet() {
    Get.bottomSheet(Container(
      width: Get.width,
      height: Get.height * 0.8,
      padding: const EdgeInsets.only(left: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
            topRight: Radius.circular(12), topLeft: Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            height: 10,
          ),
          // Center(
          //   child: Container(
          //     width: Get.width * 0.2,
          //     height: 8,
          //     decoration: BoxDecoration(
          //         borderRadius: BorderRadius.circular(8), color: Colors.grey),
          //   ),
          // ),
          // const SizedBox(
          //   height: 20,
          // ),
          textWidget(
              text: 'Select a patient condition:',
              fontSize: 18,
              fontWeight: FontWeight.bold),
          const SizedBox(
            height: 10,
          ),
          //  buildDriversList(),
          //   const SizedBox(
          //     height: 20,
          //   ),
          const Padding(
            padding: EdgeInsets.only(right: 20),
            child: Divider(),
          ),
          // Padding(
          //   padding: const EdgeInsets.only(right: 20),
          //   child: Row(
          //     crossAxisAlignment: CrossAxisAlignment.center,
          //     children: [
          //       Expanded(child: buildPaymentCardWidget()),
          //       MaterialButton(
          //         onPressed: () {},
          //         color: AppColors.greenColor,
          //         shape: const StadiumBorder(),
          //         child: textWidget(
          //           text: 'Confirm',
          //           color: Colors.white,
          //         ),
          //       )
          //     ],
          //  ),
          // )
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Column(
              //radio button
              children: <Widget>[
                ListTile(
                  title: const Text('Road Accident'),
                  leading: Radio<PatientCondition>(
                    value: PatientCondition.roadAccident,
                    groupValue: _condition,
                    onChanged: (PatientCondition? value) {
                      setState(() {
                        _condition = value;
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Covid'),
                  leading: Radio<PatientCondition>(
                    value: PatientCondition.covid,
                    groupValue: _condition,
                    onChanged: (PatientCondition? value) {
                      print(value);
                      print(_condition);
                      setState(() {
                        _condition = value;
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Heart Attack'),
                  leading: Radio<PatientCondition>(
                    value: PatientCondition.heartAttack,
                    groupValue: _condition,
                    onChanged: (PatientCondition? value) {
                      setState(() {
                        _condition = value;
                      });
                      print(value);
                      print(_condition);
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Bone Injury'),
                  leading: Radio<PatientCondition>(
                    value: PatientCondition.boneInjury,
                    groupValue: _condition,
                    onChanged: (PatientCondition? value) {
                      setState(() {
                        _condition = value;
                      });
                      print(value);
                      print(_condition);
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Poisoning'),
                  leading: Radio<PatientCondition>(
                    value: PatientCondition.poisoning,
                    groupValue: _condition,
                    onChanged: (PatientCondition? value) {
                      setState(() {
                        _condition = value;
                      });
                      print(value);
                      print(_condition);
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Pregnancy'),
                  leading: Radio<PatientCondition>(
                    value: PatientCondition.pregnancy,
                    groupValue: _condition,
                    onChanged: (PatientCondition? value) {
                      setState(() {
                        _condition = value;
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Other'),
                  leading: Radio<PatientCondition>(
                    value: PatientCondition.other,
                    groupValue: _condition,
                    onChanged: (PatientCondition? value) {
                      setState(() {
                        _condition = value;
                      });
                    },
                  ),
                ),

                // Container(
                //   //Confirm Button
                //   child: MaterialButton(
                //             onPressed: () {},
                //             color: AppColors.greenColor,
                //             shape: const StadiumBorder(),
                //             child: textWidget(
                //               text: 'Confirm',
                //               color: Colors.white,
                //             ),
                // ))
              ],
            ),
          )
        ],
      ),
    ));
  }

  int selectedRide = 0;

  // buildDriversList() {
  //   return SizedBox(
  //     height: 90,
  //     width: Get.width,
  //     child: StatefulBuilder(builder: (context, set) {
  //       return ListView.builder(
  //         itemBuilder: (ctx, i) {
  //           return InkWell(
  //             onTap: () {
  //               set(() {
  //                 selectedRide = i;
  //               });
  //             },
  //             child: buildDriverCard(selectedRide == i),
  //           );
  //         },
  //         itemCount: 3,
  //         scrollDirection: Axis.horizontal,
  //       );
  //     }),
  //   );
  // }

  // buildDriverCard(bool selected) {
  //   return Container(
  //     margin: const EdgeInsets.only(right: 8, left: 8, top: 4, bottom: 4),
  //     height: 85,
  //     width: 165,
  //     decoration: BoxDecoration(
  //         boxShadow: [
  //           BoxShadow(
  //               color: selected
  //                   ? const Color(0xff2DBB54).withOpacity(0.2)
  //                   : Colors.grey.withOpacity(0.2),
  //               offset: const Offset(0, 5),
  //               blurRadius: 5,
  //               spreadRadius: 1)
  //         ],
  //         borderRadius: BorderRadius.circular(12),
  //         color: selected ? const Color(0xffFF0000) : Colors.grey),
  //     child: Stack(
  //       children: [
  //         Container(
  //           padding:
  //               const EdgeInsets.only(left: 10, top: 10, bottom: 10, right: 10),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               textWidget(
  //                   text: 'Standard',
  //                   color: Colors.white,
  //                   fontWeight: FontWeight.w700),
  //               textWidget(
  //                   text: '\$9.90',
  //                   color: Colors.white,
  //                   fontWeight: FontWeight.w500),
  //               textWidget(
  //                   text: '3 MIN',
  //                   color: Colors.white.withOpacity(0.8),
  //                   fontWeight: FontWeight.normal,
  //                   fontSize: 12),
  //             ],
  //           ),
  //         ),
  //         Positioned(
  //             right: -20,
  //             top: 0,
  //             bottom: 0,
  //             child: Image.asset('assets/Mask Group 2.png'))
  //       ],
  //     ),
  //   );
  // }

  // buildPaymentCardWidget() {
  //   return Row(
  //     mainAxisAlignment: MainAxisAlignment.center,
  //     crossAxisAlignment: CrossAxisAlignment.center,
  //     children: [
  //       Image.asset(
  //         'assets/visa.png',
  //         width: 40,
  //       ),
  //       const SizedBox(
  //         width: 10,
  //       ),
  //       DropdownButton<String>(
  //         value: dropdownValue,
  //         icon: const Icon(Icons.keyboard_arrow_down),
  //         elevation: 16,
  //         style: const TextStyle(color: Colors.deepPurple),
  //         underline: Container(),
  //         onChanged: (String? value) {
  //           // This is called when the user selects an item.
  //           setState(() {
  //             dropdownValue = value!;
  //           });
  //         },
  //         items: list.map<DropdownMenuItem<String>>((String value) {
  //           return DropdownMenuItem<String>(
  //             value: value,
  //             child: textWidget(text: value),
  //           );
  //         }).toList(),
  //       )
  //     ],
  //   );
  // }
}
