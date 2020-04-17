import 'dart:async';
import 'dart:ffi';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devcom/profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:devcom/const.dart';
import 'package:devcom/main.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'devcom',
      theme: ThemeData(
        primaryColor: themeColor,
      ),
      home: LoginScreen(title: 'devcom'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginScreen extends StatefulWidget {
  LoginScreen({Key key, this.title}) : super(key: key);

  final String title;

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  SharedPreferences prefs;

  var showDialog;
  String formemail = '';
  String formpassword ='';
  String verificationid = '';
  String smscode = '';
  String error = '';
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool isLoggedIn = false;
  FirebaseUser currentUser;
  bool _obscureText = true;

  void _toggle() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }
 
  @override
  void initState() {
    super.initState();
    isSignedIn();
  }

  void isSignedIn() async {
    this.setState(() {
      isLoading = true;
    });

    prefs = await SharedPreferences.getInstance();

    isLoggedIn = await googleSignIn.isSignedIn();
    if (isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MainScreen(currentUserId: prefs.getString('id'))),
      );
    }

    this.setState(() {
      isLoading = false;
    });
  }

  final _codeController = TextEditingController();
  final _phoneController = TextEditingController();

  // phone number sign in
  Future<void> phoneNumberLogIn(String phone, BuildContext context) async{

    this.setState(() {
      isLoading = true;
    });

    FirebaseAuth _auth = FirebaseAuth.instance;

    _auth.verifyPhoneNumber(
      phoneNumber: phone, 
      
      timeout: Duration(seconds: 60), 
      
      verificationCompleted: (AuthCredential credential)async{
        Navigator.of(context).pop();
        AuthResult result = await _auth.signInWithCredential(credential);
        FirebaseUser firebaseUser = result.user;

        if (firebaseUser != null) {
          // Check is already sign up
          final QuerySnapshot result =
              await Firestore.instance.collection('users').where('id', isEqualTo: firebaseUser.uid).getDocuments();
          final List<DocumentSnapshot> documents = result.documents;
          if (documents.length == 0) {
            // Update data to server if new user
            Firestore.instance.collection('users').document(firebaseUser.uid).setData({
              'username': firebaseUser.displayName,
              'phoneNumber': firebaseUser.phoneNumber,
              'photoUrl': firebaseUser.photoUrl,
              'id': firebaseUser.uid,
              'createdAt': DateTime.now().millisecondsSinceEpoch.toString(),
              'chattingWith': null
            });

            // Write data to local
            currentUser = firebaseUser;
            await prefs.setString('id', currentUser.uid);
            await prefs.setString('username', currentUser.displayName);
            await prefs.setString('phoneNumber', currentUser.phoneNumber);
            await prefs.setString('photoUrl', currentUser.photoUrl);

             this.setState(() {
            isLoading = false;
            });

            Navigator.push(context, MaterialPageRoute(builder: (context) => Profile()));
          } else {
            // Write data to local
            await prefs.setString('id', documents[0]['id']);
            await prefs.setString('username', documents[0]['username']);
            await prefs.setString('phoneNumber', documents[0]['phoneNumber']);
            await prefs.setString('photoUrl', documents[0]['photoUrl']);
            await prefs.setString('status', documents[0]['status']);
             Fluttertoast.showToast(msg: "Sign in success");
          this.setState(() {
            isLoading = false;
          });

          Navigator.push(context, MaterialPageRoute(builder: (context) => MainScreen(currentUserId: firebaseUser.uid)));
          }
         
        } else {
          Fluttertoast.showToast(msg: "Sign in fail");
          this.setState(() {
            isLoading = false;
          });
        }
      }, 
      
      verificationFailed: (AuthException e) {
        print(e);
        print(e.message);
        Fluttertoast.showToast(msg: "Sign in fail");
          this.setState(() {
            isLoading = false;
          });
      },  
      
      codeSent: (String verificationId, [int forceResendingtoken]){
        showModalBottomSheet(
          shape: RoundedRectangleBorder(
            borderRadius: new BorderRadius.all(Radius.circular(50.0)),
          ),
          context: context, 
          builder: (context){
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 30.0, vertical : 20.0),
              child: Column(
                children: <Widget>[
                  new Text(
                    'Enter the code',
                    style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w800, color: primaryColor),
                  ),
                  new Text(
                    'If it does not sign in atuomatically.',
                    style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w300, color: primaryColor),
                  ),
                  new SizedBox(height: 10.0),
                  TextField(
                    controller: _codeController,
                  ),
                  new SizedBox(height: 10.0), 
                  FlatButton(
                    child: Text("Confirm"),
                    textColor: Colors.white,
                    color: primaryColor,
                    onPressed: () async{
                      final code = _codeController.text.trim();
                      AuthCredential credential = PhoneAuthProvider.getCredential(verificationId: verificationId, smsCode: code);

                      AuthResult result = await _auth.signInWithCredential(credential);

                      FirebaseUser firebaseUser = result.user;

                      if (firebaseUser != null) {
                        // Check is already sign up
                        final QuerySnapshot result =
                            await Firestore.instance.collection('users').where('id', isEqualTo: firebaseUser.uid).getDocuments();
                        final List<DocumentSnapshot> documents = result.documents;
                        if (documents.length == 0) {
                          // Update data to server if new user
                          Firestore.instance.collection('users').document(firebaseUser.uid).setData({
                            'username': firebaseUser.displayName,
                            'phoneNumber': firebaseUser.phoneNumber,
                            'photoUrl': firebaseUser.photoUrl,
                            'id': firebaseUser.uid,
                            'createdAt': DateTime.now().millisecondsSinceEpoch.toString(),
                            'chattingWith': null
                          });

                          // Write data to local
                          currentUser = firebaseUser;
                          await prefs.setString('id', currentUser.uid);
                          await prefs.setString('username', currentUser.displayName);
                          await prefs.setString('phoneNumber', currentUser.phoneNumber);
                          await prefs.setString('photoUrl', currentUser.photoUrl);
                          Fluttertoast.showToast(msg: "Sign in success");
                            this.setState(() {
                              isLoading = false;
                            });
                          Navigator.push(context, MaterialPageRoute(builder: (context) => Profile()));
                        } else {
                          // Write data to local
                          await prefs.setString('id', documents[0]['id']);
                          await prefs.setString('username', documents[0]['username']);
                          await prefs.setString('phoneNumber', documents[0]['phoneNumber']);
                          await prefs.setString('photoUrl', documents[0]['photoUrl']);
                          await prefs.setString('status', documents[0]['status']);
                          Fluttertoast.showToast(msg: "Sign in success");
                            this.setState(() {
                              isLoading = false;
                            });
                          Navigator.push(context, MaterialPageRoute(builder: (context) => MainScreen(currentUserId: firebaseUser.uid)));
                        }
                        

                      } else {
                        Fluttertoast.showToast(msg: "Sign in fail");
                        this.setState(() {
                          isLoading = false;
                        });
                      }

                    }
                  ),
                ],
              ),
            );
          }
        );
      }, 
      
      codeAutoRetrievalTimeout: (String verID){
         this.verificationid = verID;
      },
    );
  }

  // register using email and password
  Future<Null> signUpWithEmailAndPassword(String email, String password) async{

    this.setState(() {
      isLoading = true;
    });

    AuthResult result = await firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
    FirebaseUser firebaseUser = result.user;
    if (firebaseUser != null) {
      // Check is already sign up
      final QuerySnapshot result =
          await Firestore.instance.collection('users').where('id', isEqualTo: firebaseUser.uid).getDocuments();
      final List<DocumentSnapshot> documents = result.documents;
      if (documents.length == 0) {
        // Update data to server if new user
        Firestore.instance.collection('users').document(firebaseUser.uid).setData({
          'username': firebaseUser.displayName,
          'phoneNumber': firebaseUser.phoneNumber,
          'photoUrl': firebaseUser.photoUrl,
          'id': firebaseUser.uid,
          'createdAt': DateTime.now().millisecondsSinceEpoch.toString(),
          'chattingWith': null
        });

        // Write data to local
        currentUser = firebaseUser;
        await prefs.setString('id', currentUser.uid);
        await prefs.setString('username', currentUser.displayName);
        await prefs.setString('phoneNumber', currentUser.phoneNumber);
        await prefs.setString('photoUrl', currentUser.photoUrl);
      } else {
        // Write data to local
        await prefs.setString('id', documents[0]['id']);
        await prefs.setString('username', documents[0]['username']);
        await prefs.setString('phoneNumber', documents[0]['phoneNumber']);
        await prefs.setString('photoUrl', documents[0]['photoUrl']);
        await prefs.setString('status', documents[0]['status']);
      }
      Fluttertoast.showToast(msg: "Sign in success");
      this.setState(() {
        isLoading = false;
      });

      Navigator.push(context, MaterialPageRoute(builder: (context) => Profile()));
    } else {
      Fluttertoast.showToast(msg: "Sign in fail");
      this.setState(() {
        isLoading = false;
      });
    }
    
  }


  // sign in with email and password
  Future<Null> signInWithEmailAndPassword(String email, String password) async{

    this.setState(() {
      isLoading = true;
    });

    AuthResult result = await firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    FirebaseUser firebaseUser = result.user;
  

    if (firebaseUser != null) {
      // Check is already sign up
      final QuerySnapshot result =
          await Firestore.instance.collection('users').where('id', isEqualTo: firebaseUser.uid).getDocuments();
      final List<DocumentSnapshot> documents = result.documents;
      if (documents.length == 0) {
        // Update data to server if new user
        Firestore.instance.collection('users').document(firebaseUser.uid).setData({
          'username': firebaseUser.displayName,
          'photoUrl': firebaseUser.photoUrl,
          'id': firebaseUser.uid,
          'createdAt': DateTime.now().millisecondsSinceEpoch.toString(),
          'chattingWith': null
        });

        // Write data to local
        currentUser = firebaseUser;
        await prefs.setString('id', currentUser.uid);
        await prefs.setString('username', currentUser.displayName);
        await prefs.setString('photoUrl', currentUser.photoUrl);
      } else {
        // Write data to local
        await prefs.setString('id', documents[0]['id']);
        await prefs.setString('username', documents[0]['username']);
        await prefs.setString('phoneNumber', documents[0]['phoneNumber ']);
        await prefs.setString('photoUrl', documents[0]['photoUrl']);
        await prefs.setString('status', documents[0]['status']);
      // }
      Fluttertoast.showToast(msg: "Sign in success");
      this.setState(() {
        isLoading = false;
      });

      Navigator.push(context, MaterialPageRoute(builder: (context) => MainScreen(currentUserId: firebaseUser.uid)));
      }
    } else {
      Fluttertoast.showToast(msg: "Sign in fail");
      this.setState(() {
        isLoading = false;
      });
    }
  }

  // google sign in
  Future<Null> handleSignIn() async {
    prefs = await SharedPreferences.getInstance();

    this.setState(() {
      isLoading = true;
    });

    GoogleSignInAccount googleUser = await googleSignIn.signIn();
    GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.getCredential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    FirebaseUser firebaseUser = (await firebaseAuth.signInWithCredential(credential)).user;

    if (firebaseUser != null) {
      // Check is already sign up
      final QuerySnapshot result =
          await Firestore.instance.collection('users').where('id', isEqualTo: firebaseUser.uid).getDocuments();
      final List<DocumentSnapshot> documents = result.documents;
      if (documents.length == 0) {
        // Update data to server if new user
        Firestore.instance.collection('users').document(firebaseUser.uid).setData({
          'username': firebaseUser.displayName,
          'photoUrl': firebaseUser.photoUrl,
          'phoneNumber': firebaseUser.phoneNumber,
          'id': firebaseUser.uid,
          'createdAt': DateTime.now().millisecondsSinceEpoch.toString(),
          'chattingWith': null
        });

        // Write data to local
        currentUser = firebaseUser;
        await prefs.setString('id', currentUser.uid);
        await prefs.setString('username', currentUser.displayName);
        await prefs.setString('phoneNumber', currentUser.phoneNumber);
        await prefs.setString('photoUrl', currentUser.photoUrl);
      } else {
        // Write data to local
        await prefs.setString('id', documents[0]['id']);
        await prefs.setString('username', documents[0]['username']);
        await prefs.setString('phoneNumber', documents[0]['phoneNumber']);
        await prefs.setString('photoUrl', documents[0]['photoUrl']);
        await prefs.setString('status', documents[0]['status']);
      }
      Fluttertoast.showToast(msg: "Sign in success");
      this.setState(() {
        isLoading = false;
      });

      Navigator.push(context, MaterialPageRoute(builder: (context) => MainScreen(currentUserId: firebaseUser.uid)));
    } else {
      Fluttertoast.showToast(msg: "Sign in fail");
      this.setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
          color: primaryColor,
          child: Stack(
            children: <Widget>[
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                    Text(
                      'devcom.',
                      style: TextStyle(
                        color: themeColor,
                        fontSize: 32.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.5),
                    new Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 20.0),
                          width: 300,
                          child: new RaisedButton(
                            elevation: 10.0,
                            shape: RoundedRectangleBorder(
                              borderRadius: new BorderRadius.circular(18.0),
                            ),
                            onPressed: (){
                              showModalBottomSheet(
                                shape: RoundedRectangleBorder(
                                  borderRadius: new BorderRadius.all(Radius.circular(50.0)),
                                ),
                                isScrollControlled: true,
                                context: context, 
                                builder: (context) { 
                                  return Container(
                                    padding: EdgeInsets.symmetric(vertical: 100.0, horizontal: 30.0),
                                    child: new Form(
                                      key: _formKey,
                                      child: new Column(
                                        children: <Widget>[
                                          new Text(
                                            'Register',
                                            style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w800, color: primaryColor),
                                          ),
                                          new SizedBox(height: 10.0,),
                                          new TextFormField(
                                            decoration: InputDecoration(
                                              prefixIcon: Icon(Icons.email, color: Colors.black,),
                                              labelText: 'Email',
                                            ),
                                            onChanged: (val) => formemail = val,
                                          ),
                                          new SizedBox(height: 10.0,),
                                          new TextFormField(
                                            autocorrect: false,
                                            decoration: InputDecoration(
                                              prefixIcon: Icon(Icons.vpn_key, color: Colors.black,),
                                              labelText: 'Password',
                                              suffixIcon: new IconButton(
                                                color: Colors.black,
                                                icon: Icon( _obscureText ? Icons.visibility_off : Icons.visibility), 
                                                onPressed: () => _toggle()
                                              ),
                                            ),
                                            onChanged: (val) => formpassword = val,
                                          ),
                                          new SizedBox(height: 10.0,),
                                          SizedBox(height: 20.0),
                                          new RaisedButton(
                                            shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(8.0),),
                                            color: primaryColor,
                                            child: new Text('Sign Up', style: TextStyle(color: Colors.white),),
                                             onPressed: () async {
                                              Navigator.pop(context);
                                              setState(() => isLoading = true);
                                              if(_formKey.currentState.validate()){
                                                dynamic result = await signUpWithEmailAndPassword(formemail, formpassword);
                                                if(result == null){
                                                  if (this.mounted){
                                                    setState(
                                                      (){ 
                                                        isLoading = false;
                                                        error = "Error: Please enter a valid email address.";
                                                      });
                                                    }
                                                }
                                              }
                                            }
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              );
                            },
                            child: Text(
                              'Register',
                              style: TextStyle(fontSize: 14.0),
                            ),
                            color: Colors.white,
                            highlightColor: Color(0xffff7f7f),
                            splashColor: Colors.transparent,
                            textColor: primaryColor,
                            padding: EdgeInsets.fromLTRB(30.0, 15.0, 30.0, 15.0)
                          ),
                        ),
                        SizedBox(height: 20.0),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 20.0),
                          width: 300,
                          child: new RaisedButton(
                            elevation: 10.0,
                            shape: RoundedRectangleBorder(
                              borderRadius: new BorderRadius.circular(18.0),
                            ),
                            onPressed: (){
                              showModalBottomSheet(
                                shape: RoundedRectangleBorder(
                                  borderRadius: new BorderRadius.all(Radius.circular(50.0)),
                                ),
                                isScrollControlled: true,
                                context: context, 
                                builder: (context) { 
                                  return Container(
                                    padding: EdgeInsets.symmetric(vertical: 100.0, horizontal: 30.0),
                                    child: new Form(
                                      key: _formKey,
                                      child: new Column(
                                        children: <Widget>[
                                          new Text(
                                            'Sign In',
                                            style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w800, color: primaryColor),
                                          ),
                                          new SizedBox(height: 20.0,),
                                          new TextFormField(
                                            decoration: InputDecoration(
                                              prefixIcon: Icon(Icons.email, color: Colors.black,),
                                              labelText: 'Email',
                                            ),
                                            onChanged: (val) => formemail = val,
                                          ),
                                          new SizedBox(height: 10.0,),
                                          new TextFormField(
                                            autocorrect: false,
                                            obscureText: _obscureText,
                                            decoration: InputDecoration(
                                              prefixIcon: Icon(Icons.vpn_key, color: Colors.black,),
                                              labelText: 'Password',
                                              suffixIcon: new IconButton(
                                                color: Colors.black,
                                                icon: Icon( _obscureText ? Icons.visibility_off : Icons.visibility), 
                                                onPressed: () => _toggle(),
                                              ),
                                            ),
                                            onChanged: (val) => formpassword = val,
                                          ),
                                          SizedBox(height: 20.0),
                                          new RaisedButton(
                                            shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(8.0),),
                                            color: primaryColor,
                                            child: new Text('Sign In', style: TextStyle(color: Colors.white),),
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              if(_formKey.currentState.validate()){
                                                setState(() => isLoading = true);
                                                dynamic result = await signInWithEmailAndPassword(formemail, formpassword);
                                                if(result == null){
                                                  if (this.mounted){
                                                    setState(
                                                      (){
                                                        isLoading = false; 
                                                        error = "Error: Please enter a valid email address.";
                                                      });
                                                    }
                                                }
                                              }
                                            },
                                          ),
                                          new SizedBox(height: 12.0),
                                          new Text(
                                            error,
                                            style: TextStyle(color: Colors.red, fontSize: 12.0),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              );
                            },
                            child: Text(
                              'Sign In',
                              style: TextStyle(fontSize: 12.0),
                            ),
                            color: Colors.white,
                            highlightColor: Color(0xffff7f7f),
                            splashColor: Colors.transparent,
                            textColor: primaryColor,
                            padding: EdgeInsets.fromLTRB(30.0, 15.0, 30.0, 15.0)
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.0,),
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 60.0),
                      child: Row(
                        children: <Widget>[
                          Expanded(child: Divider(color: themeColor,)),
                          Container(padding: EdgeInsets.symmetric(horizontal: 5.0),child: Text('OR CONNECT WITH', style: TextStyle(color: themeColor),)),
                          Expanded(child: Divider(color: themeColor,)),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.0),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        InkWell(
                          child: CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: 20.0,
                            child: Image.asset('images/googlelogo.png'),
                          ),
                          onTap: handleSignIn,
                        ),
                        SizedBox(width:30.0),
                        InkWell(
                          child: CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(Icons.call, color: Colors.white,),
                            radius: 20.0,
                          ),
                          onTap: (){
                            showModalBottomSheet(
                              shape: RoundedRectangleBorder(
                                  borderRadius: new BorderRadius.all(Radius.circular(50.0)),
                                ),
                                isScrollControlled: true,
                              context: context, 
                              builder: (context){
                                return Container(
                                  padding: EdgeInsets.symmetric(vertical: 100.0, horizontal: 40.0),
                                  child: new Form(
                                    child: new Column(
                                      children: <Widget>[
                                        Text('Sign in with Phone number',
                                        style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w800, color: primaryColor),
                                        ),
                                        SizedBox(height: 20.0),
                                        TextFormField(
                                          keyboardType: TextInputType.number,
                                          controller: _phoneController,
                                          decoration: InputDecoration(
                                            fillColor: primaryColor,
                                            prefixIcon: Icon(Icons.phone, color: Colors.black,),
                                            labelText: 'Mobile Number',
                                          ),
                                        ),
                                        SizedBox(height: 20.0),
                                        new RaisedButton(
                                            shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(8.0),),
                                            color: primaryColor,
                                            child: new Text('Sign In', style: TextStyle(color: Colors.white),),
                                            onPressed: () async {
                                              final _phone = _phoneController.text.trim();
                                              print(_phone);
                                              phoneNumberLogIn("+91"+_phone, context);
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    // RaisedButton(
                    //   elevation: 10.0,
                    //   shape: RoundedRectangleBorder(
                    //     borderRadius: new BorderRadius.circular(18.0),
                    //   ),
                    //   onPressed: handleSignIn,
                    //   child: Text(
                    //     'Google Sign In',
                    //     style: TextStyle(fontSize: 12.0),
                    //   ),
                    //   color: themeColor,
                    //   highlightColor: Color(0xffff7f7f),
                    //   splashColor: Colors.transparent,
                    //   textColor: primaryColor,
                    //   padding: EdgeInsets.fromLTRB(30.0, 15.0, 30.0, 15.0)
                    // ),
                  ],
                ),
              

              // Loading
              Positioned(
                child: isLoading
                    ? Container(
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                          ),
                        ),
                        color: Colors.white.withOpacity(0.8),
                      )
                    : Container(),
              ),
            ],
          ),
        ));
  }
}
