import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePictureWidget extends StatefulWidget {
  final String? avatarUrl; // Current URL from Firestore
  const ProfilePictureWidget({Key? key, this.avatarUrl}) : super(key: key);

  @override
  State<ProfilePictureWidget> createState() => _ProfilePictureWidgetState();
}

class _ProfilePictureWidgetState extends State<ProfilePictureWidget> {
  File? _imageFile;
  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);

      if (picked == null) return; // User cancelled

      setState(() {
        _imageFile = File(picked.path);
        _isUploading = true;
      });

      final user = FirebaseAuth.instance.currentUser!;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pics/${user.uid}/avatar.jpg');

      // Upload image
      await storageRef.putFile(File(picked.path));

      // Get download URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firestore user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'avatarUrl': downloadUrl});

      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageToShow = _imageFile != null
        ? FileImage(_imageFile!)
        : (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
            ? NetworkImage(widget.avatarUrl!)
            : null);

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey[300],
          backgroundImage: imageToShow as ImageProvider<Object>?,
          child: imageToShow == null
              ? const Icon(Icons.person, size: 50, color: Colors.white)
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 4,
          child: InkWell(
            onTap: _isUploading ? null : _pickAndUploadImage,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue,
              child: _isUploading
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.edit, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}
