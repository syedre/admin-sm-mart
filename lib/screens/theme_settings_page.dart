import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _defaultTheme = <String, String>{
  'theme_name': 'Premium Fresh Market',
  'primary': '#246B45',
  'background': '#F5F8F2',
  'surface': '#FFFFFF',
  'text': '#1C2B22',
  'muted': '#78867B',
  'border': '#E5EBE2',
  'accent': '#A6C96A',
  'festival_effect': '',
};

const _presets = <String, Map<String, String>>{
  'Premium Fresh Market': _defaultTheme,
  'Classic SM mart': {
    'theme_name': 'Classic SM mart',
    'primary': '#246B45',
    'background': '#FAF8F3',
    'surface': '#FFFFFF',
    'text': '#18231C',
    'muted': '#778078',
    'border': '#E8E9E4',
    'accent': '#A6C96A',
    'festival_effect': '',
  },
  'Midnight Green': {
    'theme_name': 'Midnight Green',
    'primary': '#8BC7A0',
    'background': '#101B15',
    'surface': '#1A2920',
    'text': '#F1F7F2',
    'muted': '#A9B8AD',
    'border': '#314238',
    'accent': '#C4E58A',
    'festival_effect': '',
  },
  'Diwali Celebration': {
    'theme_name': 'Diwali Celebration',
    'primary': '#8B3F18',
    'background': '#FFF8EC',
    'surface': '#FFFFFF',
    'text': '#302015',
    'muted': '#887466',
    'border': '#F0DFCA',
    'accent': '#D9A441',
    'festival_effect': 'diwali',
  },
  'Holi Festival': {
    'theme_name': 'Holi Festival',
    'primary': '#7A3F78',
    'background': '#FFF8FB',
    'surface': '#FFFFFF',
    'text': '#302333',
    'muted': '#887B8B',
    'border': '#EEDFEB',
    'accent': '#E59A43',
    'festival_effect': 'holi',
  },
  'Sankranti Harvest': {
    'theme_name': 'Sankranti Harvest',
    'primary': '#426B35',
    'background': '#FFF9E9',
    'surface': '#FFFFFF',
    'text': '#26301F',
    'muted': '#7C806B',
    'border': '#EAE2C9',
    'accent': '#D9A52B',
    'festival_effect': 'sankranti',
  },
  'Eid Elegance': {
    'theme_name': 'Eid Elegance',
    'primary': '#185B50',
    'background': '#F4FAF7',
    'surface': '#FFFFFF',
    'text': '#1D302B',
    'muted': '#748780',
    'border': '#DCEAE4',
    'accent': '#C6A45B',
    'festival_effect': 'eid',
  },
  'Christmas Fresh': {
    'theme_name': 'Christmas Fresh',
    'primary': '#8A2932',
    'background': '#FFF8F5',
    'surface': '#FFFFFF',
    'text': '#302122',
    'muted': '#887477',
    'border': '#EFDFDF',
    'accent': '#3D8053',
    'festival_effect': 'christmas',
  },
};

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  final _fields = <String, TextEditingController>{};
  final _headerImageUrlController = TextEditingController();
  String _preset = 'Premium Fresh Market';
  String _festivalEffect = '';
  String _headerImageUrl = '';
  String _headerStyle = 'gradient';
  String _headerImagePosition = 'center';
  double _headerOverlayOpacity = 0.48;
  bool _uploadingHeader = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _labels = <String, String>{
    'primary': 'Primary colour',
    'background': 'App background',
    'surface': 'Cards and surfaces',
    'text': 'Main text',
    'muted': 'Muted text',
    'border': 'Borders',
    'accent': 'Accent colour',
  };

  @override
  void initState() {
    super.initState();
    for (final key in _labels.keys) {
      _fields[key] = TextEditingController(text: _defaultTheme[key]);
    }
    _load();
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _headerImageUrlController.dispose();
    super.dispose();
  }

  Color _color(String key) {
    final raw = _fields[key]?.text.trim().replaceFirst('#', '') ?? '';
    final value = int.tryParse(raw, radix: 16);
    return value == null || raw.length != 6
        ? Colors.transparent
        : Color(0xFF000000 | value);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await Supabase.instance.client
          .from('shop_settings')
          .select('theme_config')
          .eq('id', 1)
          .single();
      final config = row['theme_config'];
      if (config is Map) {
        for (final key in _labels.keys) {
          final value = config[key]?.toString();
          if (value != null && value.isNotEmpty) _fields[key]!.text = value;
        }
        _festivalEffect = config['festival_effect']?.toString() ?? '';
        _headerImageUrl = config['header_image_url']?.toString() ?? '';
        _headerImageUrlController.text = _headerImageUrl;
        _headerStyle = config['header_style']?.toString() ?? 'gradient';
        _headerImagePosition = config['header_image_position']?.toString() ?? 'center';
        _headerOverlayOpacity = (double.tryParse(config['header_overlay_opacity']?.toString() ?? '') ?? 0.48).clamp(0.0, 0.85).toDouble();
        final name = config['theme_name']?.toString();
        if (name != null && _presets.containsKey(name)) _preset = name;
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applyPreset(String? name) {
    if (name == null) return;
    final preset = _presets[name]!;
    setState(() {
      _preset = name;
      _festivalEffect = preset['festival_effect'] ?? '';
      for (final key in _labels.keys) {
        _fields[key]!.text = preset[key]!;
      }
    });
  }


  Future<void> _pickHeaderImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 84,
      maxWidth: 1800,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingHeader = true);
    try {
      final bytes = await picked.readAsBytes();
      final name = picked.name.toLowerCase();
      final extension = name.endsWith('.png') ? 'png' : 'jpg';
      final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';
      final path = 'theme/header-${DateTime.now().millisecondsSinceEpoch}.$extension';
      final storage = Supabase.instance.client.storage.from('royalwood');
      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );
      final url = storage.getPublicUrl(path);
      if (mounted) {
        setState(() {
          _headerImageUrl = url;
          _headerImageUrlController.text = url;
          _headerStyle = 'image';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Header image uploaded. Publish the theme to apply it.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Header image upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingHeader = false);
    }
  }

  Future<void> _save() async {
    for (final key in _labels.keys) {
      final raw = _fields[key]!.text.trim().replaceFirst('#', '');
      if (raw.length != 6 || int.tryParse(raw, radix: 16) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter a valid 6-digit hex value for ${_labels[key]}.')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final config = <String, dynamic>{
        'version': 1,
        'theme_name': _preset,
        'festival_effect': _festivalEffect,
        'header_image_url': _headerImageUrl,
        'header_style': _headerStyle,
        'header_image_position': _headerImagePosition,
        'header_overlay_opacity': _headerOverlayOpacity,
        for (final key in _labels.keys)
          key: '#${_fields[key]!.text.trim().replaceFirst('#', '').toUpperCase()}',
        'published_at': DateTime.now().toUtc().toIso8601String(),
      };
      final savedRow = await Supabase.instance.client
          .from('shop_settings')
          .update({
            'theme_config': config,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', 1)
          .select('id, theme_config')
          .maybeSingle();

      // PostgREST UPDATE can return no error when RLS filters the row or
      // when the id does not match. Never report a publish as successful
      // unless Supabase returns the row that was actually updated.
      if (savedRow == null || savedRow['theme_config'] is! Map) {
        throw Exception(
          'No shop_settings row was updated. Check that the settings row has id = 1 '
          'and that the admin role has an UPDATE policy for shop_settings.',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer app theme published successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is PostgrestException ? e.message : e.toString())),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final previewBackground = _color('background');
    final previewSurface = _color('surface');
    final previewText = _color('text');
    final previewPrimary = _color('primary');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer app theme'),
        actions: [
          IconButton(onPressed: _load, tooltip: 'Reload theme', icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [previewPrimary, previewPrimary.withValues(alpha: .78)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.palette_rounded, color: Colors.white, size: 25),
                SizedBox(height: 10),
                Text('Make SM mart feel yours', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Preview your colours, then publish them to the customer app.', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Choose a starting theme', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 9),
          DropdownButtonFormField<String>(
            initialValue: _preset,
            decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.color_lens_outlined)),
            items: _presets.keys.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
            onChanged: _applyPreset,
          ),
          const SizedBox(height: 8),
          Text(
            _festivalEffect.isEmpty
                ? 'Header animation: None'
                : 'Header animation: ${_festivalEffect[0].toUpperCase()}${_festivalEffect.substring(1)}',
            style: const TextStyle(color: Color(0xFF68736B), fontSize: 12, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 20),
          const Text('Home header background', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 148,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                if (_headerStyle == 'image' && _headerImageUrl.isNotEmpty)
                  Image.network(
                    _headerImageUrl,
                    fit: BoxFit.cover,
                    alignment: _headerImagePosition == 'top'
                        ? Alignment.topCenter
                        : _headerImagePosition == 'bottom'
                            ? Alignment.bottomCenter
                            : Alignment.center,
                    errorBuilder: (_, __, ___) => Container(color: previewPrimary),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [previewPrimary, previewPrimary.withValues(alpha: .72)]),
                    ),
                  ),
                Container(color: previewPrimary.withValues(alpha: _headerOverlayOpacity)),
                const Positioned(
                  left: 16,
                  bottom: 16,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('SM mart', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                    SizedBox(height: 5),
                    Text('Fresh groceries, delivered.', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _headerImageUrlController,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Header image URL',
              hintText: 'Paste a public image URL (https://...)',
              helperText: 'Use a publicly accessible image URL, or upload an image above.',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link_rounded),
            ),
            onChanged: (value) {
              _headerImageUrl = value.trim();
              if (_headerImageUrl.isNotEmpty) _headerStyle = 'image';
            },
            onSubmitted: (value) => setState(() {
              _headerImageUrl = value.trim();
              if (_headerImageUrl.isNotEmpty) _headerStyle = 'image';
            }),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: _uploadingHeader ? null : _pickHeaderImage,
              icon: _uploadingHeader
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.photo_library_outlined),
              label: Text(_uploadingHeader ? 'Uploading…' : 'Upload image'),
            ),
            if (_headerImageUrl.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() {
                  _headerImageUrl = '';
                  _headerImageUrlController.clear();
                  _headerStyle = 'gradient';
                }),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove image'),
              ),
          ]),
          DropdownButtonFormField<String>(
            initialValue: _headerStyle,
            decoration: const InputDecoration(labelText: 'Header background style', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'image', child: Text('Uploaded image')),
              DropdownMenuItem(value: 'gradient', child: Text('Dynamic brand gradient')),
              DropdownMenuItem(value: 'solid', child: Text('Solid brand colour')),
            ],
            onChanged: (value) => setState(() => _headerStyle = value ?? 'gradient'),
          ),
          const SizedBox(height: 10),
          Text('Colour overlay · ${(_headerOverlayOpacity * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Slider(
            value: _headerOverlayOpacity,
            min: 0,
            max: 0.85,
            divisions: 17,
            onChanged: (value) => setState(() => _headerOverlayOpacity = value),
          ),
          DropdownButtonFormField<String>(
            initialValue: _headerImagePosition,
            decoration: const InputDecoration(labelText: 'Image position', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'center', child: Text('Center')),
              DropdownMenuItem(value: 'top', child: Text('Top')),
              DropdownMenuItem(value: 'bottom', child: Text('Bottom')),
            ],
            onChanged: (value) => setState(() => _headerImagePosition = value ?? 'center'),
          ),

          const SizedBox(height: 20),
          const Text('Customize colours', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text('Use 6-digit hex values, for example #246B45.', style: TextStyle(color: Color(0xFF68736B), fontSize: 12)),
          const SizedBox(height: 10),
          ..._labels.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: _fields[entry.key],
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: entry.value,
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _color(entry.key),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: const Color(0x22000000)),
                    ),
                    child: const SizedBox(width: 22, height: 22),
                  ),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
              ),
            ),
          )),
          const SizedBox(height: 8),
          const Text('Live preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: previewBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _color('border')),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('SM mart', style: TextStyle(color: previewText, fontSize: 19, fontWeight: FontWeight.w900))),
                Icon(Icons.shopping_basket_outlined, color: previewPrimary),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: previewSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _color('border'))),
                child: Row(children: [
                  Icon(Icons.local_grocery_store_outlined, color: previewPrimary, size: 28),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Fresh picks for you', style: TextStyle(color: previewText, fontWeight: FontWeight.w800)),
                    Text('Quality groceries, delivered fresh.', style: TextStyle(color: _color('muted'), fontSize: 11)),
                  ])),
                ]),
              ),
              const SizedBox(height: 11),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: previewPrimary, foregroundColor: previewBackground.computeLuminance() < .35 ? Colors.black : Colors.white),
                  onPressed: () {},
                  child: const Text('Continue shopping'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.publish_rounded),
              label: Text(_saving ? 'Publishing…' : 'Publish customer theme'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text('Could not load the saved theme: $_error', style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
