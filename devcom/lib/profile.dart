import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devcom/login.dart';
import 'package:devcom/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:devcom/const.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Profile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      backgroundColor: primaryColor,
      appBar: new PreferredSize(
          preferredSize: Size.fromHeight(MediaQuery.of(context).size.height*0.15),
          child: new AppBar(
            iconTheme: IconThemeData(color: themeColor),
            backgroundColor: primaryColor,
            elevation: 0.0,
          title: new Text(
            'Profile',
            style: TextStyle(color: themeColor, fontSize: 24.0,fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
      ),
      body: new ProfileScreen(),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  @override
  State createState() => new ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  TextEditingController controllerUsername;
  TextEditingController controllerstatus;
  TextEditingController controllerPhone;

  SharedPreferences prefs;

  String id = '';
  String username = '';
  String status = '';
  String phoneNumber = '';
  String photoUrl = '';

  bool isLoading = false;
  File avatarImageFile;

  final FocusNode focusNodeUsername = new FocusNode();
  final FocusNode focusNodestatus = new FocusNode();
  final FocusNode focusNodePhone = new FocusNode();

  @override
  void initState() {
    super.initState();
    readLocal();
  }


  void readLocal() async {
    prefs = await SharedPreferences.getInstance();
    id = prefs.getString('id') ?? '';
    username = prefs.getString('username') ?? '';
    phoneNumber = prefs.getString('phoneNumber') ?? '';
    status = prefs.getString('status') ?? '';
    photoUrl = prefs.getString('photoUrl') ?? '';

    controllerUsername = new TextEditingController(text: username);
    controllerstatus = new TextEditingController(text: status);
    controllerPhone = new TextEditingController(text: phoneNumber);

    // Force refresh input
    setState(() {});
  }

  Future getImage() async {
    File image = await ImagePicker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        avatarImageFile = image;
        isLoading = true;
      });
    }
    uploadFile();
  }
  String firebaseUserUid = '';
  Future<Null> firebaseUser() async{
   FirebaseUser firebaseUser = await (FirebaseAuth.instance).currentUser();
    firebaseUserUid = firebaseUser.uid;
  }

  Future uploadFile() async {
    String fileName = id;
    StorageReference reference = FirebaseStorage.instance.ref().child(fileName);
    StorageUploadTask uploadTask = reference.putFile(avatarImageFile);
    StorageTaskSnapshot storageTaskSnapshot;
    uploadTask.onComplete.then((value) {
      if (value.error == null) {
        storageTaskSnapshot = value;
        storageTaskSnapshot.ref.getDownloadURL().then((downloadUrl) {
          photoUrl = downloadUrl;
          Firestore.instance
              .collection('users')
              .document(id)
              .updateData({'username': username, 'status': status, 'photoUrl': photoUrl, 'phoneNumber': phoneNumber}).then((data) async {
            await prefs.setString('photoUrl', photoUrl);
            setState(() {
              isLoading = false;
            });
            Fluttertoast.showToast(msg: "Upload success");
          }).catchError((err) {
            setState(() {
              isLoading = false;
            });
            Fluttertoast.showToast(msg: err.toString());
          });
        }, onError: (err) {
          setState(() {
            isLoading = false;
          });
          Fluttertoast.showToast(msg: 'This file is not an image');
        });
      } else {
        setState(() {
          isLoading = false;
        });
        Fluttertoast.showToast(msg: 'This file is not an image');
      }
    }, onError: (err) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: err.toString());
    });
  }

  void handleUpdateData() {
    focusNodeUsername.unfocus();
    focusNodestatus.unfocus();
    focusNodePhone.unfocus();

    setState(() {
      isLoading = true;
    });

    Firestore.instance
        .collection('users')
        .document(id)
        .updateData({'username': username, 'status': status, 'photoUrl': photoUrl}).then((data) async {
      await prefs.setString('username', username);
      await prefs.setString('status', status);
      await prefs.setString('phoneNumber', phoneNumber);
      await prefs.setString('photoUrl', photoUrl);

      setState(() {
        isLoading = false;
      });

      Fluttertoast.showToast(msg: "Update success");
      Navigator.push(context, MaterialPageRoute(builder: (context) => MainScreen(currentUserId: firebaseUserUid)));
    }).catchError((err) {
      setState(() {
        isLoading = false;
      });

      Fluttertoast.showToast(msg: err.toString());
    });
  }
  final GoogleSignIn googleSignIn = GoogleSignIn();
  Future<Null> handleSignOut() async {
    this.setState(() {
      isLoading = true;
    });

    await FirebaseAuth.instance.signOut();
    await googleSignIn.disconnect();
    await googleSignIn.signOut();

    this.setState(() {
      isLoading = false;
    });

    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => MyApp()),
        (Route<dynamic> route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(50), topRight: Radius.circular(50.0))
        ),
      child: Stack(
        children: <Widget>[
          SingleChildScrollView(
            child: Column(
              children: <Widget>[
                // Avatar
                Container(
                  child: Center(
                    child: Stack(
                      children: <Widget>[
                        (avatarImageFile == null)
                            ? (photoUrl != ''
                                ? Material(
                                    child: CachedNetworkImage(
                                      placeholder: (context, url) => Container(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.0,
                                              valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                                            ),
                                            width: 90.0,
                                            height: 90.0,
                                            padding: EdgeInsets.all(20.0),
                                          ),
                                      imageUrl: photoUrl,
                                      width: 90.0,
                                      height: 90.0,
                                      fit: BoxFit.cover,
                                    ),
                                    borderRadius: BorderRadius.all(Radius.circular(45.0)),
                                    clipBehavior: Clip.hardEdge,
                                  )
                                : Icon(
                                    Icons.account_circle,
                                    size: 90.0,
                                    color: greyColor,
                                  ))
                            : Material(
                                child: Image.file(
                                  avatarImageFile,
                                  width: 90.0,
                                  height: 90.0,
                                  fit: BoxFit.cover,
                                ),
                                borderRadius: BorderRadius.all(Radius.circular(45.0)),
                                clipBehavior: Clip.hardEdge,
                              ),
                        IconButton(
                          icon: Icon(
                            Icons.camera_alt,
                            color: primaryColor.withOpacity(0.5),
                          ),
                          onPressed: getImage,
                          padding: EdgeInsets.all(30.0),
                          splashColor: Colors.transparent,
                          highlightColor: greyColor,
                          iconSize: 30.0,
                        ),
                      ],
                    ),
                  ),
                  width: double.infinity,
                  margin: EdgeInsets.all(20.0),
                ),

                // Input
                Column(
                  children: <Widget>[
                    // phone number
                     Container(
                      child: Text(
                        'Mobile Number',
                        style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                      ),
                      margin: EdgeInsets.only(left: 10.0, bottom: 5.0, top: 10.0),
                    ),
                    Container(
                      child: Theme(
                        data: Theme.of(context).copyWith(primaryColor: primaryColor),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Mobile Number',
                            contentPadding: new EdgeInsets.all(5.0),
                            hintStyle: TextStyle(color: greyColor),
                          ),
                          controller: controllerPhone,
                          onChanged: (value) {
                            phoneNumber = value;
                          },
                          focusNode: focusNodePhone,
                        ),
                      ),
                      margin: EdgeInsets.only(left: 30.0, right: 30.0),
                    ),
                    // Username
                    Container(
                      child: Text(
                        'Username',
                        style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                      ),
                      margin: EdgeInsets.only(left: 10.0, bottom: 5.0, top: 10.0),
                    ),
                    Container(
                      child: Theme(
                        data: Theme.of(context).copyWith(primaryColor: primaryColor),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Username',
                            contentPadding: new EdgeInsets.all(5.0),
                            hintStyle: TextStyle(color: greyColor),
                          ),
                          controller: controllerUsername,
                          onChanged: (value) {
                            username = value;
                          },
                          focusNode: focusNodeUsername,
                        ),
                      ),
                      margin: EdgeInsets.only(left: 30.0, right: 30.0),
                    ),

                    // Status
                    Container(
                      child: Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                      ),
                      margin: EdgeInsets.only(left: 10.0, top: 30.0, bottom: 5.0),
                    ),
                    Container(
                      child: Theme(
                        data: Theme.of(context).copyWith(primaryColor: primaryColor),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Status',
                            contentPadding: EdgeInsets.all(5.0),
                            hintStyle: TextStyle(color: greyColor),
                          ),
                          controller: controllerstatus,
                          onChanged: (value) {
                            status = value;
                          },
                          focusNode: focusNodestatus,
                        ),
                      ),
                      margin: EdgeInsets.only(left: 30.0, right: 30.0),
                    ),
                  ],
                  crossAxisAlignment: CrossAxisAlignment.start,
                ),

                // Button
                Container(
                  child: RaisedButton(
                    elevation: 5.0,
                    shape: RoundedRectangleBorder(
                        borderRadius: new BorderRadius.circular(18.0),
                    ),
                    onPressed: handleUpdateData,
                    child: Text(
                      'Update',
                      style: TextStyle(fontSize: 16.0),
                    ),
                    color: primaryColor,
                    highlightColor: new Color(0xff8d93a0),
                    splashColor: Colors.transparent,
                    textColor: Colors.white,
                    padding: EdgeInsets.fromLTRB(30.0, 10.0, 30.0, 10.0),
                  ),
                  margin: EdgeInsets.only(top: 20.0, bottom: 20.0),
                ),
                FlatButton.icon(
                  onPressed: () => handleSignOut(), icon: Icon(Icons.exit_to_app), label: Text('Sign out')
                ),
              ],
            ),
            padding: EdgeInsets.only(left: 15.0, right: 15.0),
          ),

          // Loading
          Positioned(
            child: isLoading
                ? Container(
                    child: Center(
                      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(themeColor)),
                    ),
                    color: Colors.white.withOpacity(0.8),
                  )
                : Container(),
          ),
        ],
      ),
    );
  }
}
