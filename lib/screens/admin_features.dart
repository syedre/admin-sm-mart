import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final db = Supabase.instance.client;
const green = Color(0xFF246B45);
const muted = Color(0xFF68736B);
String money(num? n) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(n ?? 0);
String orderMoney(num? n) => money((n ?? 0) / 100);
String messageOf(Object e) => e is PostgrestException ? e.message : e.toString();
InputDecoration dec(String label) => InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));
void toast(BuildContext c, String text, {bool error = false}) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? Colors.red : green));
Map<String,dynamic>? firstMatch(List<Map<String,dynamic>> rows, bool Function(Map<String,dynamic>) test) {
  for (final row in rows) { if (test(row)) return row; } return null;
}
Widget section(String title, String note) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
  const SizedBox(height: 3), Text(note, style: const TextStyle(fontSize: 12, color: muted)),
]));
Widget empty(String text) => Padding(padding: const EdgeInsets.all(28), child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: muted))));


class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({required this.label,required this.value,required this.icon,this.accent=false});
  final String label,value;
  final IconData icon;
  final bool accent;
  @override
  Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[
    Container(width:34,height:34,decoration:BoxDecoration(color:accent?const Color(0xFFE8F2EB):const Color(0xFFF1F2EE),borderRadius:BorderRadius.circular(11)),child:Icon(icon,size:18,color:green)),
    const SizedBox(width:9),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(value,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,height:1.1)),
      const SizedBox(height:3),
      Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,color:muted,fontWeight:FontWeight.w600)),
    ])),
  ])));
}

class _AdminStatusTag extends StatelessWidget {
  const _AdminStatusTag({required this.label,required this.active,this.color});
  final String label;
  final bool active;
  final Color? color;
  @override
  Widget build(BuildContext context){
    final tint=color??(active?green:muted);
    return Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:tint.withValues(alpha:.10),borderRadius:BorderRadius.circular(20)),child:Text(label,style:TextStyle(color:tint,fontSize:10,fontWeight:FontWeight.w800)));
  }
}

class CataloguePage extends StatefulWidget { const CataloguePage({super.key}); @override State<CataloguePage> createState()=>_CataloguePageState(); }
class _CataloguePageState extends State<CataloguePage> {
  bool loading=true; String search='', categoryFilter='all', visibilityFilter='all'; List<Map<String,dynamic>> products=[], categories=[], homes=[];
  @override void initState(){super.initState();load();}
  Future<void> load() async {
    setState(()=>loading=true);
    try {
      final r=await Future.wait([
        db.from('products').select('product_id,name,description,price,mrp,unit,stock_quantity,image_url,is_active,category_id,home_page_status,inventory_quantity,inventory_unit,created_at').order('created_at',ascending:false),
        db.from('product_category').select('id,name,is_active,img_url').order('name'),
        db.from('enum_table').select('id,name').order('name'),
      ]);
      products=List<Map<String,dynamic>>.from(r[0]); categories=List<Map<String,dynamic>>.from(r[1]); homes=List<Map<String,dynamic>>.from(r[2]);
    } catch(e){if(mounted)toast(context,messageOf(e),error:true);}
    if(mounted)setState(()=>loading=false);
  }
  Future<void> addCategory() async {
    final c=TextEditingController();
    final name=await showDialog<String>(context:context,builder:(x)=>AlertDialog(title:const Text('Add category'),content:TextField(controller:c,decoration:dec('Category name')),actions:[TextButton(onPressed:()=>Navigator.pop(x),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(x,c.text.trim()),child:const Text('Add'))]));
    if(!mounted||name==null||name.isEmpty)return;
    try { if(categories.any((x)=>(x['name']??'').toString().toLowerCase()==name.toLowerCase())){toast(context,'Category already exists.',error:true);return;} await db.from('product_category').insert({'name':name,'is_active':true}); await load(); }
    catch(e){if(mounted)toast(context,messageOf(e),error:true);}
  }
  Future<void> toggle(Map<String,dynamic> p) async {try{await db.from('products').update({'is_active':p['is_active']!=true}).eq('product_id',p['product_id']);await load();}catch(e){if(mounted)toast(context,messageOf(e),error:true);}}
  Future<void> toggleCategory(Map<String,dynamic> c) async {try{await db.from('product_category').update({'is_active':c['is_active']!=true}).eq('id',c['id']);await load();}catch(e){if(mounted)toast(context,messageOf(e),error:true);}}
  Future<void> edit([Map<String,dynamic>? p]) async {final result=await showModalBottomSheet<bool>(context:context,isScrollControlled:true,useSafeArea:true,builder:(_)=>ProductEditor(product:p,categories:categories,homes:homes));if(result==true)load();}
  @override Widget build(BuildContext context){
    final query=search.trim().toLowerCase();
    final list=products.where((p){
      final matchesName=(p['name']??'').toString().toLowerCase().contains(query);
      final matchesCategory=categoryFilter=='all'||p['category_id']?.toString()==categoryFilter;
      final matchesVisibility=visibilityFilter=='all'||(visibilityFilter=='visible'?p['is_active']==true:p['is_active']!=true);
      return matchesName&&matchesCategory&&matchesVisibility;
    }).toList();
    if(loading)return const Center(child:CircularProgressIndicator());
    final visible=products.where((p)=>p['is_active']==true).length;
    return RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.fromLTRB(16,16,16,28),children:[
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(child:section('Product catalogue','Manage products, pricing and visibility')),
        IconButton(tooltip:'Add category',onPressed:addCategory,icon:const Icon(Icons.create_new_folder_outlined)),
        FilledButton.icon(onPressed:()=>edit(),icon:const Icon(Icons.add_rounded),label:const Text('Add product')),
      ]),
      Row(children:[
        Expanded(child:_AdminStatCard(label:'All products',value:'${products.length}',icon:Icons.inventory_2_outlined)),
        const SizedBox(width:9),
        Expanded(child:_AdminStatCard(label:'Visible',value:'$visible',icon:Icons.visibility_outlined,accent:true)),
      ]),
      const SizedBox(height:14),
      TextField(decoration:dec('Search products').copyWith(prefixIcon:const Icon(Icons.search_rounded),hintText:'Name of a product'),onChanged:(v)=>setState(()=>search=v)),
      const SizedBox(height:10),
      DropdownButtonFormField<String>(initialValue:categoryFilter,isExpanded:true,decoration:dec('Category').copyWith(prefixIcon:const Icon(Icons.category_outlined),isDense:true),items:[const DropdownMenuItem(value:'all',child:Text('All categories')),...categories.map((cat)=>DropdownMenuItem(value:cat['id'].toString(),child:Text(cat['name']??'Category')))],onChanged:(v)=>setState(()=>categoryFilter=v??'all')),
      const SizedBox(height:9),
      Wrap(spacing:8,children:[
        ChoiceChip(label:const Text('All'),selected:visibilityFilter=='all',onSelected:(_)=>setState(()=>visibilityFilter='all')),
        ChoiceChip(label:const Text('Visible'),selected:visibilityFilter=='visible',onSelected:(_)=>setState(()=>visibilityFilter='visible')),
        ChoiceChip(label:const Text('Hidden'),selected:visibilityFilter=='hidden',onSelected:(_)=>setState(()=>visibilityFilter='hidden')),
      ]),
      const SizedBox(height:8),
      Row(children:[Expanded(child:Text('${list.length} products',style:const TextStyle(color:muted,fontSize:12,fontWeight:FontWeight.w600))),TextButton.icon(onPressed:()=>setState(() { search=''; categoryFilter='all'; visibilityFilter='all'; }),icon:const Icon(Icons.filter_alt_off_outlined,size:16),label:const Text('Clear filters'))]),
      ...list.map((p){
        final cat=firstMatch(categories,(x)=>x['id']==p['category_id']);
        final active=p['is_active']==true;
        return Card(margin:const EdgeInsets.only(bottom:9),child:Padding(padding:const EdgeInsets.all(11),child:Row(children:[
          ClipRRect(borderRadius:BorderRadius.circular(13),child:Container(width:66,height:66,color:const Color(0xFFF1F3EF),child:p['image_url']!=null?Image.network(p['image_url'],fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.image_not_supported_outlined,color:muted)):const Icon(Icons.image_outlined,color:muted,size:27))),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(p['name']??'Product',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:14)),
            const SizedBox(height:4),
            Text('${cat?['name']??'Uncategorised'} · ${p['unit']??''}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:muted,fontSize:11)),
            const SizedBox(height:6),
            Wrap(spacing:7,runSpacing:4,crossAxisAlignment:WrapCrossAlignment.center,children:[
              Text(money((p['price'] as num?)?.toDouble()),style:const TextStyle(fontWeight:FontWeight.w800,fontSize:13,color:green)),
              Text('Stock ${p['stock_quantity']??0}',style:const TextStyle(fontSize:11,color:muted)),
              _AdminStatusTag(label:active?'Visible':'Hidden',active:active),
            ]),
          ])),
          PopupMenuButton<String>(tooltip:'Product actions',onSelected:(v){if(v=='edit'){edit(p);}else{toggle(p);}},itemBuilder:(_)=>[const PopupMenuItem(value:'edit',child:Text('Edit product')),PopupMenuItem(value:'toggle',child:Text(active?'Hide product':'Show product'))]),
        ])));
      }),
      if(list.isEmpty)empty('No products match these filters.'),
      const SizedBox(height:18),
      section('Categories','Control which categories customers can browse'),
      ...categories.map((cat)=>Card(margin:const EdgeInsets.only(bottom:7),child:SwitchListTile(
        value:cat['is_active']==true,onChanged:(_)=>toggleCategory(cat),activeThumbColor:green,
        secondary:Container(width:38,height:38,decoration:BoxDecoration(color:const Color(0xFFEAF2EC),borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.category_outlined,color:green,size:19)),
        title:Text(cat['name']??'Category',style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
        subtitle:Text(cat['is_active']==true?'Shown in the customer catalogue':'Hidden from the customer catalogue',style:const TextStyle(fontSize:11,color:muted)),
      ))),
    ]));
  }
}

class ProductEditor extends StatefulWidget {
  const ProductEditor({super.key,this.product,required this.categories,required this.homes});
  final Map<String,dynamic>? product; final List<Map<String,dynamic>> categories,homes;
  @override State<ProductEditor> createState()=>_ProductEditorState();
}
class _ProductEditorState extends State<ProductEditor>{
  final form=GlobalKey<FormState>(); late TextEditingController name,description,price,mrp,unit,stock;
  String? category,home; XFile? image; bool remove=false,saving=false;

  // Keep dropdown values unique and retain a product's existing category even
  // if that category is inactive or missing from the latest category query.
  List<Map<String, dynamic>> get categoryOptions {
    final seen = <String>{};
    final options = <Map<String, dynamic>>[];
    for (final item in widget.categories) {
      final id = item['id']?.toString();
      if (id != null && seen.add(id)) options.add(item);
    }
    final currentId = widget.product?['category_id']?.toString();
    if (currentId != null && currentId.isNotEmpty && seen.add(currentId)) {
      options.add({'id': currentId, 'name': 'Current category'});
    }
    return options;
  }
  // Homepage section is stored as enum_table.id, not enum_table.name.
  // Keep IDs unique and preserve an existing value if its option is unavailable.
  List<Map<String, dynamic>> get homeOptions {
    final seen = <String>{};
    final options = <Map<String, dynamic>>[];
    for (final item in widget.homes) {
      final id = item['id']?.toString();
      if (id != null && seen.add(id)) options.add(item);
    }
    final currentId = widget.product?['home_page_status']?.toString();
    if (currentId != null && currentId.isNotEmpty && seen.add(currentId)) {
      options.add({'id': currentId, 'name': 'Current section'});
    }
    return options;
  }
  @override void initState(){super.initState();final p=widget.product;name=TextEditingController(text:p?['name']??'');description=TextEditingController(text:p?['description']??'');price=TextEditingController(text:p?['price']?.toString()??'');mrp=TextEditingController(text:p?['mrp']?.toString()??'');unit=TextEditingController(text:p?['unit']??'1 kg');stock=TextEditingController(text:p?['stock_quantity']?.toString()??'0');category=p?['category_id']?.toString()??firstMatch(widget.categories,(c)=>c['is_active']==true)?['id']?.toString();home=p?['home_page_status']?.toString();}
  @override void dispose(){name.dispose();description.dispose();price.dispose();mrp.dispose();unit.dispose();stock.dispose();super.dispose();}
  Future<void> save() async {
    if(!form.currentState!.validate()||category==null)return;
    if(widget.product!=null&&unit.text.trim()!=(widget.product!['unit']??'').toString().trim()){toast(context,'Change the selling pack label in Pack sizes to keep shared stock consistent.',error:true);return;}
    setState(()=>saving=true);
    try{
      String? imageUrl=remove?null:widget.product?['image_url']?.toString();
      if(image!=null){final ext=image!.name.split('.').last.toLowerCase().replaceAll('jpeg','jpg');final path='product/images/${DateTime.now().millisecondsSinceEpoch}.$ext';await db.storage.from('royalwood').uploadBinary(path,await image!.readAsBytes(),fileOptions:FileOptions(contentType:image!.mimeType??'image/jpeg',cacheControl:'3600',upsert:false));imageUrl=db.storage.from('royalwood').getPublicUrl(path);}
      final payload={'name':name.text.trim(),'description':description.text.trim().isEmpty?null:description.text.trim(),'price':double.parse(price.text),'mrp':mrp.text.trim().isEmpty?null:double.parse(mrp.text),'stock_quantity':int.parse(stock.text),'category_id':category,'image_url':imageUrl,'home_page_status':home==''?null:home};
      if(widget.product==null){await db.from('products').insert({...payload,'unit':unit.text.trim(),'is_active':true});}
      else{
        await db.from('products').update(payload).eq('product_id',widget.product!['product_id']);
        final v=await db.from('product_variants').select('variant_id,inventory_quantity_per_pack').eq('product_id',widget.product!['product_id']).order('sort_order').order('created_at').limit(1).maybeSingle();
        if(v!=null){final amount=(v['inventory_quantity_per_pack'] as num?)?.toDouble()??1;await db.from('products').update({'inventory_quantity':int.parse(stock.text)*amount}).eq('product_id',widget.product!['product_id']);await db.from('product_variants').update({'variant_name':unit.text.trim(),'unit_label':unit.text.trim(),'price':double.parse(price.text),'mrp':mrp.text.trim().isEmpty?null:double.parse(mrp.text),'updated_at':DateTime.now().toUtc().toIso8601String()}).eq('variant_id',v['variant_id']);}
      }
      if(mounted)Navigator.pop(context,true);
    }catch(e){if(mounted)toast(context,messageOf(e),error:true);}
    if(mounted)setState(()=>saving=false);
  }
  @override Widget build(BuildContext context)=>Padding(padding:EdgeInsets.only(left:16,right:16,top:16,bottom:MediaQuery.viewInsetsOf(context).bottom+16),child:Form(key:form,child:ListView(shrinkWrap:true,children:[
    Text(widget.product==null?'Add product':'Edit product',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
    const SizedBox(height:12),TextFormField(controller:name,decoration:dec('Product name'),validator:(v)=>v==null||v.trim().isEmpty?'Required':null),
    const SizedBox(height:8),TextFormField(controller:description,decoration:dec('Description'),maxLines:2),
    const SizedBox(height:8),Row(children:[Expanded(child:TextFormField(controller:price,decoration:dec('Price ₹'),keyboardType:const TextInputType.numberWithOptions(decimal:true),validator:(v)=>double.tryParse(v??'')==null?'Invalid price':null)),const SizedBox(width:8),Expanded(child:TextFormField(controller:mrp,decoration:dec('MRP ₹'),keyboardType:const TextInputType.numberWithOptions(decimal:true)))]),
    const SizedBox(height:8),Row(children:[Expanded(child:TextFormField(controller:unit,decoration:dec('Unit'),validator:(v)=>v==null||v.trim().isEmpty?'Required':null)),const SizedBox(width:8),Expanded(child:TextFormField(controller:stock,decoration:dec('Stock'),keyboardType:TextInputType.number,validator:(v)=>int.tryParse(v??'')==null?'Invalid stock':null))]),
    const SizedBox(height:8),DropdownButtonFormField<String>(initialValue:category,decoration:dec('Category'),items:categoryOptions.map((c)=>DropdownMenuItem<String>(value:c['id'].toString(),child:Text(c['name']??'Category'))).toList(),onChanged:(v)=>setState(()=>category=v)),
    const SizedBox(height:8),DropdownButtonFormField<String>(initialValue:home??'',decoration:dec('Homepage section'),items:[const DropdownMenuItem<String>(value:'',child:Text('None')),...homeOptions.map((h)=>DropdownMenuItem<String>(value:h['id'].toString(),child:Text(h['name']??'Section')))],onChanged:(v)=>setState(()=>home=v)),
    OutlinedButton.icon(onPressed:()async{final x=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:82,maxWidth:1600);if(x!=null)setState(()=>image=x);},icon:const Icon(Icons.image),label:Text(image?.name??'Choose product image')),
    if(widget.product?['image_url']!=null)TextButton(onPressed:()=>setState(()=>remove=true),child:const Text('Remove current image')),
    const SizedBox(height:10),FilledButton(onPressed:saving?null:save,child:Text(saving?'Saving…':'Save product')),
  ])));
}

class OrdersPage extends StatefulWidget{const OrdersPage({super.key});@override State<OrdersPage> createState()=>_OrdersPageState();}
class _OrdersPageState extends State<OrdersPage>{
  bool loading=true;String search='',filter='all',statusFilter='all';List<Map<String,dynamic>> orders=[];
  final labels={'placed':'Placed','confirmed':'Confirmed','preparing':'Preparing','out_for_delivery':'Out for delivery','delivered':'Delivered','cancelled':'Cancelled'};
  final next={'placed':'confirmed','confirmed':'preparing','preparing':'out_for_delivery','out_for_delivery':'delivered'};
  String get today=>DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc().add(const Duration(hours:5,minutes:30)));
  String shift(int d)=>DateFormat('yyyy-MM-dd').format(DateTime.parse(today).add(Duration(days:d)));
  @override void initState(){super.initState();load();}
  Future<void> load()async{setState(()=>loading=true);try{
    final rows=await db.from('orders').select('id,order_number,user_id,status,payment_method,payment_status,total_cents,created_at,delivery_date,address_label,address_line,apartment,landmark,city,state,postal_code,latitude,longitude,order_items(id,product_name,product_unit,quantity,unit_price_cents)').order('created_at',ascending:false);
    orders=List<Map<String,dynamic>>.from(rows);final ids=orders.map((o)=>o['user_id']).whereType<String>().toSet().toList();
    if(ids.isNotEmpty){try{final phones=await db.rpc('admin_customer_phones',params:{'p_user_ids':ids});for(final o in orders){final p=firstMatch(List<Map<String,dynamic>>.from(phones),(r)=>r['user_id']==o['user_id']);o['customer_phone']=p?['phone'];}}catch(_){}}
  }catch(e){if(mounted)toast(context,messageOf(e),error:true);}if(mounted)setState(()=>loading=false);}
  Future<void> change(Map<String,dynamic> o) async {
    final s = next[o['status']];
    if (s == null) return;
    try {
      await db.rpc('admin_update_order_status', params: {'p_order_id': o['id'], 'p_status': s});
      if (!mounted) return;
      await load();
      if (!mounted) return;
      if (s == 'confirmed') {
        try {
          await db.functions.invoke('whatsapp-order-confirmation', body: {'order_id': o['id']});
          if (mounted) toast(context, 'Order confirmed and WhatsApp confirmation submitted.');
        } catch (_) {
          if (mounted) toast(context, 'Order confirmed, but WhatsApp notification failed.', error: true);
        }
      } else {
        toast(context, 'Order updated to ${labels[s]}.');
      }
    } catch (e) {
      if (mounted) toast(context, messageOf(e), error: true);
    }
  }
  Future<void> open(String u)async{final uri=Uri.tryParse(u);if(uri!=null)await launchUrl(uri,mode:LaunchMode.externalApplication);}
  String addr(Map<String,dynamic> o)=>[o['address_line'],o['apartment'],o['landmark']==null?null:'near ${o['landmark']}',o['city'],o['state'],o['postal_code']].where((x)=>x!=null&&x.toString().isNotEmpty).join(', ');
  @override Widget build(BuildContext context){
    final q=search.trim().replaceFirst('#','').replaceAll(RegExp(r'\s+'),'');
    final todayDate=DateTime.parse(today);
    bool matchesDeliveryDate(Map<String,dynamic> order){
      if(filter=='all')return true;
      final raw=order['delivery_date']?.toString();
      if(raw==null||raw.length<10)return false;
      final parsed=DateTime.tryParse(raw.substring(0,10));
      if(parsed==null)return false;
      final day=DateTime(parsed.year,parsed.month,parsed.day);
      switch(filter){
        case 'today':return day==todayDate;
        case 'tomorrow':return day==todayDate.add(const Duration(days:1));
        case 'dayAfterTomorrow':return day==todayDate.add(const Duration(days:2));
        case 'yesterday':return day==todayDate.subtract(const Duration(days:1));
        case 'last7Days':return !day.isBefore(todayDate.subtract(const Duration(days:6)))&&!day.isAfter(todayDate);
        case 'last30Days':return !day.isBefore(todayDate.subtract(const Duration(days:29)))&&!day.isAfter(todayDate);
        case 'thisMonth':return day.year==todayDate.year&&day.month==todayDate.month;
        case 'lastMonth':final m=DateTime(todayDate.year,todayDate.month-1);return day.year==m.year&&day.month==m.month;
        default:return false;
      }
    }
    final list=orders.where((o){
      final matchesSearch=q.isNotEmpty?(o['order_number']?.toString()??'').contains(q):matchesDeliveryDate(o);
      return matchesSearch&&(statusFilter=='all'||o['status']==statusFilter);
    }).toList();
    if(loading)return const Center(child:CircularProgressIndicator());
    final active=orders.where((o)=>!['delivered','cancelled'].contains(o['status'])).length;
    final pending=orders.where((o)=>o['status']=='placed').length;
    return RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.fromLTRB(16,16,16,28),children:[
      section('Customer orders','Review, confirm and track every customer order'),
      Row(children:[
        Expanded(child:_AdminStatCard(label:'Total orders',value:'${orders.length}',icon:Icons.receipt_long_outlined)),
        const SizedBox(width:8),
        Expanded(child:_AdminStatCard(label:'In progress',value:'$active',icon:Icons.timelapse_rounded,accent:true)),
        const SizedBox(width:8),
        Expanded(child:_AdminStatCard(label:'New',value:'$pending',icon:Icons.fiber_new_rounded)),
      ]),
      const SizedBox(height:14),
      TextField(decoration:dec('Search order number').copyWith(prefixIcon:const Icon(Icons.search_rounded),hintText:'Enter order number'),keyboardType:TextInputType.number,onChanged:(v)=>setState(()=>search=v)),
      const SizedBox(height:10),
      DropdownButtonFormField<String>(initialValue:filter,isExpanded:true,decoration:dec('Delivery date').copyWith(prefixIcon:const Icon(Icons.calendar_month_outlined),isDense:true),items:const [
        DropdownMenuItem(value:'all',child:Text('All delivery dates')),
        DropdownMenuItem(value:'today',child:Text('Today')),
        DropdownMenuItem(value:'yesterday',child:Text('Yesterday')),
        DropdownMenuItem(value:'tomorrow',child:Text('Tomorrow')),
        DropdownMenuItem(value:'dayAfterTomorrow',child:Text('Day after tomorrow')),
        DropdownMenuItem(value:'last7Days',child:Text('Last 7 days')),
        DropdownMenuItem(value:'last30Days',child:Text('Last 30 days')),
        DropdownMenuItem(value:'thisMonth',child:Text('This month')),
        DropdownMenuItem(value:'lastMonth',child:Text('Last month')),
      ],onChanged:(v)=>setState(()=>filter=v??'all')),
      const SizedBox(height:9),
      DropdownButtonFormField<String>(initialValue:statusFilter,isExpanded:true,decoration:dec('Order status').copyWith(prefixIcon:const Icon(Icons.filter_list_rounded),isDense:true),items:const [
        DropdownMenuItem(value:'all',child:Text('All statuses')),
        DropdownMenuItem(value:'placed',child:Text('Placed')),
        DropdownMenuItem(value:'confirmed',child:Text('Confirmed')),
        DropdownMenuItem(value:'preparing',child:Text('Preparing')),
        DropdownMenuItem(value:'out_for_delivery',child:Text('Out for delivery')),
        DropdownMenuItem(value:'delivered',child:Text('Delivered')),
        DropdownMenuItem(value:'cancelled',child:Text('Cancelled')),
      ],onChanged:(v)=>setState(()=>statusFilter=v??'all')),
      const SizedBox(height:12),
      Row(children:[Expanded(child:Text('${list.length} matching orders',style:const TextStyle(fontSize:12,color:muted,fontWeight:FontWeight.w600))),TextButton(onPressed:()=>setState(() { search=''; filter='all'; statusFilter='all'; }),child:const Text('Reset filters'))]),
      ...list.map((o){
        final status=o['status'].toString();
        final items=List<Map<String,dynamic>>.from(o['order_items']??[]);
        final address=addr(o);
        final lat=o['latitude'],lng=o['longitude'];
        final map=lat is num&&lng is num?'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng':'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
        final phone=o['customer_phone']?.toString();
        final amount=orderMoney(o['total_cents']);
        final created=DateTime.tryParse(o['created_at']?.toString()??'');
        final statusColor=status=='placed'?const Color(0xFFB7791F):status=='confirmed'||status=='preparing'?const Color(0xFF2563A6):status=='out_for_delivery'?green:status=='cancelled'?const Color(0xFFB42318):muted;
        return Card(margin:const EdgeInsets.only(bottom:9),clipBehavior:Clip.antiAlias,child:ExpansionTile(
          tilePadding:const EdgeInsets.symmetric(horizontal:14,vertical:5),childrenPadding:const EdgeInsets.fromLTRB(14,0,14,14),
          leading:Container(width:40,height:40,decoration:BoxDecoration(color:const Color(0xFFEAF2EC),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.receipt_long_rounded,color:green,size:20)),
          title:Row(children:[Expanded(child:Text('Order #${o['order_number']}',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:14))),_AdminStatusTag(label:labels[status]??status,active:status=='out_for_delivery'||status=='delivered',color:statusColor)]),
          subtitle:Padding(padding:const EdgeInsets.only(top:4),child:Text('${created==null?'Date unavailable':DateFormat('d MMM, h:mm a').format(created.toLocal())} · $amount',style:const TextStyle(fontSize:11,color:muted))),
          children:[
            Align(alignment:Alignment.centerLeft,child:Text('Delivery date: ${o['delivery_date']??'Not set'}',style:const TextStyle(color:green,fontSize:12,fontWeight:FontWeight.w700))),
            const Divider(height:18),
            Row(children:[const Icon(Icons.person_outline,size:17,color:muted),const SizedBox(width:7),Expanded(child:Text(phone??'Customer phone unavailable',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600))),if(phone!=null)IconButton(visualDensity:VisualDensity.compact,tooltip:'Call customer',onPressed:()=>open('tel:$phone'),icon:const Icon(Icons.call_outlined,color:green))]),
            Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.location_on_outlined,size:17,color:muted),const SizedBox(width:7),Expanded(child:Text('${o['address_label']??'Delivery address'} · $address',style:const TextStyle(fontSize:12,height:1.35))),IconButton(visualDensity:VisualDensity.compact,tooltip:'Open in Maps',onPressed:()=>open(map),icon:const Icon(Icons.map_outlined,color:green))]),
            const Divider(height:18),
            ...items.map((i)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[Expanded(child:Text('${i['quantity']} × ${i['product_name']} ${i['product_unit']}',style:const TextStyle(fontSize:12))),Text(orderMoney(((i['unit_price_cents'] as num?)??0)*((i['quantity'] as num?)??0)),style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600))]))),
            const Divider(height:18),
            Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(o['payment_status']=='paid'?'Paid':'Cash on delivery',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),const Text('Payment',style:TextStyle(fontSize:10,color:muted))])),Text(amount,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))]),
            if(next.containsKey(status))Padding(padding:const EdgeInsets.only(top:12),child:SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>change(o),icon:Icon(status=='placed'?Icons.check_rounded:status=='confirmed'?Icons.soup_kitchen_outlined:status=='preparing'?Icons.local_shipping_outlined:Icons.done_all_rounded),label:Text(status=='placed'?'Confirm order':status=='confirmed'?'Start preparing':status=='preparing'?'Mark out for delivery':'Mark delivered')))),
          ],
        ));
      }),
      if(list.isEmpty)empty('No orders match the selected filters.'),
    ]));
  }
}

class PacksPage extends StatefulWidget{const PacksPage({super.key});@override State<PacksPage> createState()=>_PacksPageState();}
class _PacksPageState extends State<PacksPage>{
  bool loading=true,busy=false;List<Map<String,dynamic>> products=[],variants=[];String? selected,editing;
  final name=TextEditingController(),label=TextEditingController(),price=TextEditingController(),mrp=TextEditingController(),consumption=TextEditingController(text:'1'),stock=TextEditingController(),unit=TextEditingController(text:'unit');
  @override void initState(){super.initState();load();}
  @override void dispose(){name.dispose();label.dispose();price.dispose();mrp.dispose();consumption.dispose();stock.dispose();unit.dispose();super.dispose();}
  Map<String,dynamic>? get product=>firstMatch(products,(p)=>p['product_id']==selected);
  List<Map<String,dynamic>> get packs=>variants.where((v)=>v['product_id']==selected).toList()..sort((a,b)=>((a['sort_order'] as num?)??0).compareTo((b['sort_order'] as num?)??0));
  void reset(){editing=null;name.clear();label.clear();price.clear();mrp.clear();consumption.text='1';}
  void choose(String? id){setState((){selected=id;final p=product;stock.text=(p?['inventory_quantity']??0).toString();unit.text=p?['inventory_unit']??'unit';reset();});}
  Future<void> load()async{setState(()=>loading=true);try{final r=await Future.wait([db.from('products').select('product_id,name,unit,stock_quantity,inventory_quantity,inventory_unit,is_active').order('name'),db.from('product_variants').select('variant_id,product_id,variant_name,unit_label,price,mrp,inventory_quantity_per_pack,is_active,sort_order').order('sort_order').order('created_at')]);products=List<Map<String,dynamic>>.from(r[0]);variants=List<Map<String,dynamic>>.from(r[1]);if(selected==null&&products.isNotEmpty)choose(products.first['product_id'].toString());}catch(e){if(mounted)toast(context,messageOf(e),error:true);}if(mounted)setState(()=>loading=false);}
  void edit(Map<String,dynamic> v){setState((){editing=v['variant_id'];name.text=v['variant_name']??'';label.text=v['unit_label']??'';price.text=v['price'].toString();mrp.text=v['mrp']?.toString()??'';consumption.text=v['inventory_quantity_per_pack'].toString();});}
  Future<void> savePack()async{final p=product;final amount=double.tryParse(consumption.text),cost=double.tryParse(price.text);if(p==null||name.text.trim().isEmpty||label.text.trim().isEmpty||amount==null||amount<=0||cost==null||cost<0){toast(context,'Enter valid pack details.',error:true);return;}setState(()=>busy=true);try{final m=mrp.text.trim().isEmpty?null:double.tryParse(mrp.text);final data={'product_id':selected,'variant_name':name.text.trim(),'unit_label':label.text.trim(),'price':cost,'mrp':m,'inventory_quantity_per_pack':amount,'updated_at':DateTime.now().toUtc().toIso8601String()};if(editing!=null){await db.from('product_variants').update(data).eq('variant_id',editing!);}else{await db.from('product_variants').insert({...data,'is_active':true,'sort_order':packs.length});}final isDefaultVariant = (editing != null && packs.isNotEmpty && editing == packs.first['variant_id']) || (editing == null && packs.isEmpty);if(isDefaultVariant){final physical=(p['inventory_quantity'] as num?)?.toDouble()??0;await db.from('products').update({'price':cost,'mrp':m,'unit':label.text.trim(),'stock_quantity':(physical/amount).floor()}).eq('product_id',selected!);}reset();await load();}catch(e){if(mounted)toast(context,messageOf(e),error:true);}if(mounted)setState(()=>busy=false);}
  Future<void> saveStock() async {
    final p = product;
    final q = double.tryParse(stock.text);
    if (p == null || q == null || q < 0 || unit.text.trim().isEmpty) {
      toast(context, 'Enter valid shared stock.', error: true);
      return;
    }
    final first = packs.isEmpty ? null : packs.first;
    final per = ((first?['inventory_quantity_per_pack'] as num?) ?? 1).toDouble();
    setState(() => busy = true);
    try {
      await db.from('products').update({
        'inventory_quantity': q,
        'inventory_unit': unit.text.trim(),
        'stock_quantity': (q / per).floor(),
      }).eq('product_id', selected!);
      if (!mounted) return;
      await load();
      if (mounted) toast(context, 'Shared inventory updated.');
    } catch (e) {
      if (mounted) toast(context, messageOf(e), error: true);
    }
    if (mounted) setState(() => busy = false);
  }
  Future<void> toggle(Map<String,dynamic> v) async {
    try {
      await db.from('product_variants').update({
        'is_active': v['is_active'] != true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('variant_id', v['variant_id']);
      if (mounted) await load();
    } catch (e) {
      if (mounted) toast(context, messageOf(e), error: true);
    }
  }
  @override Widget build(BuildContext context){
    if(loading)return const Center(child:CircularProgressIndicator());
    final p=product;
    final activePacks=packs.where((v)=>v['is_active']==true).length;
    return RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.fromLTRB(16,16,16,28),children:[
      section('Pack sizes & pricing','Create selling options that draw from one shared stock balance'),
      Row(children:[
        Expanded(child:_AdminStatCard(label:'Products',value:'${products.length}',icon:Icons.inventory_2_outlined)),
        const SizedBox(width:9),
        Expanded(child:_AdminStatCard(label:'Pack options',value:'${variants.length}',icon:Icons.widgets_outlined,accent:true)),
      ]),
      const SizedBox(height:14),
      DropdownButtonFormField<String>(initialValue:selected,isExpanded:true,decoration:dec('Choose a product').copyWith(prefixIcon:const Icon(Icons.inventory_2_outlined)),items:products.map((item)=>DropdownMenuItem(value:item['product_id'].toString(),child:Text(item['name']??'Product'))).toList(),onChanged:choose),
      if(p!=null)...[
        const SizedBox(height:13),
        Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[const Expanded(child:Text('Shared inventory',style:TextStyle(fontSize:15,fontWeight:FontWeight.w800))),_AdminStatusTag(label:'Live stock',active:true)]),
          const SizedBox(height:4),
          const Text('All pack sizes consume from this physical quantity.',style:TextStyle(fontSize:11,color:muted)),
          const SizedBox(height:14),
          Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('${p['inventory_quantity']??0}',style:const TextStyle(fontSize:28,fontWeight:FontWeight.w900,height:1)),
              Text('Physical stock · ${p['inventory_unit']??'unit'}',style:const TextStyle(fontSize:11,color:muted)),
            ])),
            Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
              Text('${p['stock_quantity']??0}',style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800,color:green)),
              const Text('Default packs sellable',style:TextStyle(fontSize:10,color:muted)),
            ]),
          ]),
          const Divider(height:24),
          Row(children:[
            Expanded(child:TextField(controller:stock,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:dec('Physical quantity'))),
            const SizedBox(width:9),
            SizedBox(width:105,child:TextField(controller:unit,decoration:dec('Unit'))),
          ]),
          const SizedBox(height:10),
          SizedBox(width:double.infinity,child:FilledButton.tonalIcon(onPressed:busy?null:saveStock,icon:const Icon(Icons.save_outlined),label:const Text('Update shared stock'))),
        ]))),
        Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Text(editing==null?'Create a pack option':'Edit pack option',style:const TextStyle(fontSize:15,fontWeight:FontWeight.w800))),if(editing!=null)TextButton(onPressed:()=>setState(reset),child:const Text('Cancel'))]),
          const SizedBox(height:4),
          const Text('Set the customer-facing pack name, price and stock consumption.',style:TextStyle(fontSize:11,color:muted)),
          const SizedBox(height:13),
          TextField(controller:name,decoration:dec('Pack name')),
          const SizedBox(height:9),
          TextField(controller:label,decoration:dec('Unit label')),
          const SizedBox(height:9),
          Row(children:[
            Expanded(child:TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:dec('Selling price ₹'))),
            const SizedBox(width:9),
            Expanded(child:TextField(controller:mrp,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:dec('MRP ₹'))),
          ]),
          const SizedBox(height:9),
          TextField(controller:consumption,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:dec('Stock consumed per pack (${p['inventory_unit']??'unit'})')),
          const SizedBox(height:12),
          SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:busy?null:savePack,icon:Icon(editing==null?Icons.add_rounded:Icons.save_outlined),label:Text(busy?'Saving…':editing==null?'Add pack option':'Save changes'))),
        ]))),
        Row(children:[Expanded(child:section('Pack options','${packs.length} configured · $activePacks enabled'))]),
        if(packs.isEmpty)empty('No pack sizes yet. Add the first option above.'),
        ...packs.map((v){
          final enabled=v['is_active']==true;
          return Card(margin:const EdgeInsets.only(bottom:8),child:ListTile(
            contentPadding:const EdgeInsets.symmetric(horizontal:13,vertical:5),
            leading:Container(width:42,height:42,decoration:BoxDecoration(color:const Color(0xFFEAF2EC),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.inventory_2_outlined,color:green)),
            title:Text(v['variant_name']??'Pack',style:const TextStyle(fontSize:14,fontWeight:FontWeight.w800)),
            subtitle:Padding(padding:const EdgeInsets.only(top:4),child:Text('${v['unit_label']} · ${money((v['price'] as num?)?.toDouble())} · consumes ${v['inventory_quantity_per_pack']} ${p['inventory_unit']??'unit'}',style:const TextStyle(fontSize:11,color:muted))),
            trailing:PopupMenuButton<String>(onSelected:(action){if(action=='edit'){edit(v);}else{toggle(v);}},itemBuilder:(_)=>[const PopupMenuItem(value:'edit',child:Text('Edit pack')),PopupMenuItem(value:'toggle',child:Text(enabled?'Disable':'Enable'))]),
          ));
        }),
        const Card(child:ListTile(leading:Icon(Icons.info_outline,color:green),title:Text('Shared stock protection'),subtitle:Text('Every enabled pack option consumes from the same physical inventory.'))),
      ],
      if(products.isEmpty)empty('Add products before configuring pack sizes.'),
    ]));
  }
}

class ShopPage extends StatefulWidget{const ShopPage({super.key});@override State<ShopPage> createState()=>_ShopPageState();}
class _ShopPageState extends State<ShopPage>{
  bool loading=true,saving=false,open=true,online=true;final message=TextEditingController(text:'We are not accepting new orders right now. Please try again later.');
  @override void initState(){super.initState();load();}
  @override void dispose(){message.dispose();super.dispose();}
  Future<void> load()async{setState(()=>loading=true);try{final r=await db.from('shop_settings').select('is_open,closed_message,accepting_online_orders').eq('id',1).single();open=r['is_open']==true;online=r['accepting_online_orders']==true;message.text=r['closed_message']?.toString()??message.text;}catch(e){if(mounted)toast(context,messageOf(e),error:true);}if(mounted)setState(()=>loading=false);}
  Future<void> save({bool? isOpen,bool? isOnline})async{setState(()=>saving=true);try{final data=<String,dynamic>{'updated_at':DateTime.now().toUtc().toIso8601String()};if(isOpen!=null)data['is_open']=isOpen;if(isOnline!=null)data['accepting_online_orders']=isOnline;if(isOpen==null&&isOnline==null)data['closed_message']=message.text.trim();await db.from('shop_settings').update(data).eq('id',1);if(isOpen!=null)open=isOpen;if(isOnline!=null)online=isOnline;if(mounted)toast(context,'Shop settings saved.');}catch(e){if(mounted)toast(context,messageOf(e),error:true);}if(mounted)setState(()=>saving=false);}
  @override Widget build(BuildContext context){
    if(loading)return const Center(child:CircularProgressIndicator());
    return RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.fromLTRB(16,16,16,28),children:[
      section('Shop settings','Control store availability and customer checkout'),
      Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:open?[const Color(0xFF174C32),const Color(0xFF28764D)]:[const Color(0xFF424B45),const Color(0xFF68736B)])),child:Row(children:[
        Container(width:48,height:48,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.14),borderRadius:BorderRadius.circular(15)),child:Icon(open?Icons.storefront_rounded:Icons.storefront_outlined,color:Colors.white,size:25)),
        const SizedBox(width:13),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(open?'Your shop is open':'Your shop is closed',style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w900)),
          const SizedBox(height:4),
          Text(online?'Online checkout is enabled':'Online checkout is paused',style:const TextStyle(color:Color(0xFFDCEBE1),fontSize:11)),
        ])),
        IconButton(onPressed:load,tooltip:'Refresh settings',icon:const Icon(Icons.refresh_rounded,color:Colors.white)),
      ])),
      const SizedBox(height:16),
      const Text('Store availability',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800)),
      const SizedBox(height:8),
      Card(child:SwitchListTile(value:open,onChanged:saving?null:(value)=>save(isOpen:value),activeThumbColor:green,secondary:Container(width:40,height:40,decoration:BoxDecoration(color:const Color(0xFFEAF2EC),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.storefront_outlined,color:green)),title:Text(open?'Shop is open':'Shop is closed',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:14)),subtitle:Text(open?'Customers can browse and place COD orders.':'Browsing remains available; checkout is paused.',style:const TextStyle(fontSize:11,color:muted)))),
      const SizedBox(height:14),
      const Text('Online ordering',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800)),
      const SizedBox(height:8),
      Card(child:SwitchListTile(value:online,onChanged:saving?null:(value)=>save(isOnline:value),activeThumbColor:green,secondary:Container(width:40,height:40,decoration:BoxDecoration(color:const Color(0xFFEAF1FA),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.shopping_bag_outlined,color:Color(0xFF2563A6))),title:Text(online?'Orders are being accepted':'Orders are paused',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:14)),subtitle:const Text('Controls the existing accepting_online_orders setting.',style:TextStyle(fontSize:11,color:muted)))),
      const SizedBox(height:14),
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Row(children:[Icon(Icons.message_outlined,color:green),SizedBox(width:8),Expanded(child:Text('Checkout unavailable message',style:TextStyle(fontSize:15,fontWeight:FontWeight.w800)))]),
        const SizedBox(height:5),
        const Text('Shown to customers when checkout is unavailable.',style:TextStyle(fontSize:11,color:muted)),
        const SizedBox(height:12),
        TextField(controller:message,maxLength:220,maxLines:4,onChanged:(_)=>setState(() {}),decoration:dec('Customer-facing message')),
        const SizedBox(height:8),
        SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:saving||message.text.trim().isEmpty?null:()=>save(),icon:const Icon(Icons.save_outlined),label:Text(saving?'Saving…':'Save message'))),
      ]))),
      const SizedBox(height:8),
      const Card(child:ListTile(leading:Icon(Icons.shield_outlined,color:green),title:Text('Existing orders are safe'),subtitle:Text('Closing the shop or pausing checkout only affects new orders. Existing customer orders are not changed.'))),
    ]));
  }
}

class DeliveryPage extends StatelessWidget{
  const DeliveryPage({super.key});
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
    section('Delivery operations','Partner accounts, assignments and live delivery sessions'),
    const Card(child:Padding(padding:EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(Icons.lock_outline,size:32,color:green),SizedBox(height:10),
      Text('Secure server connection required',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
      SizedBox(height:8),
      Text('The existing web dashboard reads Firebase partners and assignments through its server-only /api/delivery route. That route authenticates with a browser cookie. This mobile app uses a Supabase bearer session, so it cannot call the route as-is.',style:TextStyle(height:1.45)),
      SizedBox(height:10),
      Text('Firebase Admin credentials must never be embedded in this app. Full mobile delivery assignment requires an additive JWT-authenticated server endpoint. No insecure direct Firebase access has been added.',style:TextStyle(height:1.45,color:muted)),
    ]))),
    const Card(child:ListTile(leading:Icon(Icons.verified_user_outlined,color:green),title:Text('Assignment safety rule'),subtitle:Text('Only orders marked Out for Delivery may be assigned. Delivered and cancelled orders must never be reassigned.'))),
  ]);
}
