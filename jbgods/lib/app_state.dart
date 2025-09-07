import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const logoUrl = 'https://s3-us-west-2.amazonaws.com/issuewireassets/primg/174378/jbgods-rose-logo269751356.jpeg';

enum AdminRequest { none, pending, approved }

class Profile {
  String username;
  String email;
  String dob;
  String address;
  String avatarUrl;
  Profile({
    required this.username,
    required this.email,
    required this.dob,
    required this.address,
    required this.avatarUrl,
  });

  factory Profile.fromPrefs(SharedPreferences prefs) => Profile(
    username: prefs.getString('profile_username') ?? 'guest',
    email: prefs.getString('profile_email') ?? 'guest@example.com',
    dob: prefs.getString('profile_dob') ?? '1990-01-18',
    address: prefs.getString('profile_address') ?? '—',
    avatarUrl: prefs.getString('profile_avatarUrl') ?? logoUrl,
  );

  Map<String, String> toPrefs() => {
    'profile_username': username,
    'profile_email': email,
    'profile_dob': dob,
    'profile_address': address,
    'profile_avatarUrl': avatarUrl,
  };

  Profile copyWith({
    String? username,
    String? email,
    String? dob,
    String? address,
    String? avatarUrl,
  }) {
    return Profile(
      username: username ?? this.username,
      email: email ?? this.email,
      dob: dob ?? this.dob,
      address: address ?? this.address,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class Event {
  String id, title, location;
  DateTime dateTime;
  Event({required this.id, required this.title, required this.location, required this.dateTime});

  factory Event.mock(int i) => Event(
    id: 'evt$i',
    title: "Event #$i – JB GODS Meetup",
    location: "Venue $i",
    dateTime: DateTime.now().add(Duration(days: i, hours: i*2)),
  );
}

class Message {
  String id, senderName, text;
  DateTime sentAt;
  bool fromAdmin;
  Message({
    required this.id,
    required this.senderName,
    required this.sentAt,
    required this.text,
    required this.fromAdmin,
  });

  factory Message.mock(int i) {
    final texts = [
      "Welcome to JB GODS!",
      "Group Rules: Be respectful.",
      "Next event at Venue 1, see Home tab.",
      "Admin Notice: New features coming soon.",
      "Contact support at support@jbgods.com.",
    ];
    return Message(
      id: 'msg$i',
      senderName: 'Admin',
      sentAt: DateTime.now().subtract(Duration(days: 5 - i)),
      text: texts[i % texts.length],
      fromAdmin: true,
    );
  }
}

class AppState {
  bool isLoggedIn;
  bool isAdmin;
  ThemeMode themeMode;
  Profile profile;
  AdminRequest adminRequest;
  List<Event> events;
  List<Message> messages;
  String lastShareScope;

  AppState({
    required this.isLoggedIn,
    required this.isAdmin,
    required this.themeMode,
    required this.profile,
    required this.adminRequest,
    required this.events,
    required this.messages,
    required this.lastShareScope,
  });

  AppState copyWith({
    bool? isLoggedIn,
    bool? isAdmin,
    ThemeMode? themeMode,
    Profile? profile,
    AdminRequest? adminRequest,
    List<Event>? events,
    List<Message>? messages,
    String? lastShareScope,
  }) =>
      AppState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        isAdmin: isAdmin ?? this.isAdmin,
        themeMode: themeMode ?? this.themeMode,
        profile: profile ?? this.profile,
        adminRequest: adminRequest ?? this.adminRequest,
        events: events ?? this.events,
        messages: messages ?? this.messages,
        lastShareScope: lastShareScope ?? this.lastShareScope,
      );
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((ref) => AppStateNotifier());

class AppStateNotifier extends StateNotifier<AppState> {
  static SharedPreferences? _prefs;
  static Future<void> ensurePrefsInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  AppStateNotifier() : super(_loadInitialState());

  static AppState _loadInitialState() {
    final prefs = _prefs;
    if (prefs == null || prefs.getBool('seeded') != true) {
      return AppState(
        isLoggedIn: false,
        isAdmin: false,
        themeMode: ThemeMode.light,
        profile: Profile(
          username: 'guest',
          email: 'guest@example.com',
          dob: '1990-01-18',
          address: '—',
          avatarUrl: logoUrl,
        ),
        adminRequest: AdminRequest.none,
        events: List.generate(6, (i) => Event.mock(i)),
        messages: List.generate(5, (i) => Message.mock(i)),
        lastShareScope: '',
      );
    }
    // Load from prefs
    final adminReqInt = prefs.getInt('adminRequest') ?? 0;
    return AppState(
      isLoggedIn: prefs.getBool('isLoggedIn') ?? false,
      isAdmin: prefs.getBool('isAdmin') ?? false,
      themeMode: ThemeMode.values[prefs.getInt('themeMode') ?? 0],
      profile: Profile.fromPrefs(prefs),
      adminRequest: AdminRequest.values[adminReqInt],
      events: [], // events/messages not persisted, just seeded
      messages: [],
      lastShareScope: prefs.getString('lastShareScope') ?? '',
    );
  }

  Future<void> _persist() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', state.isLoggedIn);
    await prefs.setBool('isAdmin', state.isAdmin);
    await prefs.setInt('themeMode', ThemeMode.values.indexOf(state.themeMode));
    for (final entry in state.profile.toPrefs().entries) {
      await prefs.setString(entry.key, entry.value);
    }
    await prefs.setInt('adminRequest', AdminRequest.values.indexOf(state.adminRequest));
    await prefs.setString('lastShareScope', state.lastShareScope);
    await prefs.setBool('seeded', true);
  }

  void logIn({bool isAdmin = false}) async {
    state = state.copyWith(isLoggedIn: true, isAdmin: isAdmin);
    await _persist();
  }

  void signUp(Profile profile) async {
    state = state.copyWith(isLoggedIn: true, profile: profile);
    await _persist();
  }

  void logOut() async {
    state = state.copyWith(isLoggedIn: false, isAdmin: false, adminRequest: AdminRequest.none);
    await _persist();
  }

  void toggleTheme() async {
    final newTheme = state.themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = state.copyWith(themeMode: newTheme);
    await _persist();
  }

  void requestAdmin() async {
    state = state.copyWith(adminRequest: AdminRequest.pending);
    await _persist();
  }

  void updateProfile(Profile profile) async {
    state = state.copyWith(profile: profile);
    await _persist();
  }

  void postAdminMessage(String text) async {
    final msg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderName: "Admin",
      sentAt: DateTime.now(),
      text: text,
      fromAdmin: true,
    );
    state = state.copyWith(messages: [...state.messages, msg]);
    await _persist();
  }

  void setShareScope(String scope) async {
    state = state.copyWith(lastShareScope: scope);
    await _persist();
  }
}