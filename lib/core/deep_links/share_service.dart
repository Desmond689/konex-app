import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'deep_link_models.dart';
import 'send_on_konex_sheet.dart';

/// Universal share sheet: Copy | Share via OS | Send on KONEX.
class ShareService {
  static Future<void> showShareSheet(
    BuildContext context, {
    required String url,
    String? title,
    WidgetRef? ref,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy link'),
              subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Share via…'),
              onTap: () async {
                Navigator.pop(ctx);
                await Share.share(url, subject: title ?? 'KONEX');
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('Send on KONEX'),
              onTap: () {
                Navigator.pop(ctx);
                if (ref != null) {
                  showSendOnKonexSheet(
                    context,
                    ref,
                    url: url,
                    previewText: title,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Open share from a screen with app state to send in chat'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> shareProfile(
    BuildContext context,
    String username, {
    WidgetRef? ref,
  }) =>
      showShareSheet(
        context,
        url: KonexLinks.profile(username),
        title: 'Profile @$username',
        ref: ref,
      );

  static Future<void> shareGame(
    BuildContext context,
    String slug, {
    WidgetRef? ref,
  }) =>
      showShareSheet(
        context,
        url: KonexLinks.game(slug),
        title: 'Game on KONEX',
        ref: ref,
      );

  static Future<void> shareSquad(
    BuildContext context, {
    String? slug,
    String? id,
    WidgetRef? ref,
  }) =>
      showShareSheet(
        context,
        url: KonexLinks.squad(slug: slug, id: id),
        title: 'Squad on KONEX',
        ref: ref,
      );

  static Future<void> sharePost(
    BuildContext context,
    String postId, {
    WidgetRef? ref,
  }) =>
      showShareSheet(
        context,
        url: KonexLinks.post(postId),
        title: 'Post on KONEX',
        ref: ref,
      );

  static Future<void> shareLfg(
    BuildContext context,
    String lfgId, {
    WidgetRef? ref,
  }) =>
      showShareSheet(
        context,
        url: KonexLinks.lfg(lfgId),
        title: 'LFG on KONEX',
        ref: ref,
      );
}
