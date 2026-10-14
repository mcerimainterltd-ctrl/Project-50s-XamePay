class XameUser {
  final String xameId;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? profilePic;
  final String? preferredName;
  final String? referralCode;
  final bool hideProfilePicture;
  final bool hidePreferredName;
  final String? personalStatusEmoji;
  final String? personalStatusMessage;
  final String? sessionToken;

  const XameUser({
    required this.xameId,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.profilePic,
    this.preferredName,
    this.referralCode,
    this.hideProfilePicture = false,
    this.hidePreferredName = false,
    this.personalStatusEmoji,
    this.personalStatusMessage,
    this.sessionToken,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get displayName =>
      preferredName?.isNotEmpty == true ? preferredName! : firstName;

  factory XameUser.fromMap(Map<String, dynamic> map) {
    final status = map['personalStatus'];

    return XameUser(
      xameId: map['xameId']?.toString() ?? '',
      firstName: map['firstName']?.toString() ?? '',
      lastName: map['lastName']?.toString() ?? '',
      email: map['email']?.toString(),
      phone: map['phone']?.toString(),
      profilePic: map['profilePic']?.toString(),
      preferredName: map['preferredName']?.toString(),
      referralCode: map['referralCode']?.toString(),
      hideProfilePicture: map['hideProfilePicture'] == true,
      hidePreferredName: map['hidePreferredName'] == true,
      personalStatusEmoji:
          status is Map ? status['emoji']?.toString() : null,
      personalStatusMessage:
          status is Map ? status['message']?.toString() : null,
      sessionToken: map['sessionToken']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'xameId': xameId,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'profilePic': profilePic,
        'preferredName': preferredName,
        'referralCode': referralCode,
        'hideProfilePicture': hideProfilePicture,
        'hidePreferredName': hidePreferredName,
        'personalStatus': {
          'emoji': personalStatusEmoji,
          'message': personalStatusMessage,
        },
      };
}
