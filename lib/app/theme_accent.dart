import 'package:flutter/material.dart';

/// Seed colors are local constants; no palette or font is fetched at runtime.
/// Chinese colors verified against https://www.zhongguose.com/colors.json.
enum LedgerAccent {
  clay('陶土', Color(0xffb75b3e)),
  bamboo('竹绿', Color(0xff1ba784)),
  azure('群青', Color(0xff1772b4)),
  vermilion('胭脂红', Color(0xfff03f24)),
  gardenia('栀子黄', Color(0xffebb10d)),
  lotus('藕荷', Color(0xffedc3ae));

  const LedgerAccent(this.label, this.seed);
  final String label;
  final Color seed;
}
