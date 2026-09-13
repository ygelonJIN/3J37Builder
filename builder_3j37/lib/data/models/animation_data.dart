class AnimTab {
  final String tabId;
  final Map<String, String> name;
  final List<AnimGroup> groups;
  const AnimTab({required this.tabId, required this.name, required this.groups});
  String getDisplayName([String locale = 'EN']) => name[locale] ?? name['EN'] ?? tabId;
}

class AnimGroup {
  final String animType;
  final Map<String, String> name;
  final List<AnimEntry> anims;
  const AnimGroup({required this.animType, required this.name, required this.anims});
  String getDisplayName([String locale = 'EN']) => name[locale] ?? name['EN'] ?? animType;
}

class AnimEntry {
  final String animId;
  final Map<String, String> name;
  final List<String> allowedSizes;
  final String? attribReqsOperator;
  final List<AnimAttribReq> attribReqs;
  final bool isPrized;
  const AnimEntry({
    required this.animId, required this.name, required this.allowedSizes,
    this.attribReqsOperator, required this.attribReqs, required this.isPrized,
  });
  String getDisplayName([String locale = 'EN']) => name[locale] ?? name['EN'] ?? animId;
}

class AnimAttribReq {
  final String attrib;
  final int value;
  const AnimAttribReq({required this.attrib, required this.value});

  factory AnimAttribReq.fromJson(Map<String, dynamic> json) =>
      AnimAttribReq(
        attrib: json['Attrib Type']?.toString() ?? '',
        value: (json['Attrib Min'] as num?)?.toInt() ?? 0,
      );
}
