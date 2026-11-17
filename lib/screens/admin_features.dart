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

class CataloguePage extends StatefulWidget { const CataloguePage({super.key}); @override State<CataloguePage> createState()=>_CataloguePageState(); }
class _CataloguePageState extends State<CataloguePage> {
  bool loading=true; String search=''; List<Map<String,dynamic>> products=[], categories=[], homes=[];
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
    final list=products.where((p)=>(p['name']??'').toString().toLowerCase().contains(search.toLowerCase())).toList();
    if(loading)return const Center(child:CircularProgressIndicator());
    return RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(16),children:[
      Row(children:[Expanded(child:section('Catalogue','${products.length} products · ${products.where((p)=>p['is_active']==true).length} visible')),IconButton(onPressed:addCategory,icon:const Icon(Icons.create_new_folder_outlined)),FilledButton.icon(onPressed:()=>edit(),icon:const Icon(Icons.add),label:const Text('Add'))]),
      TextField(decoration:dec('Search products'),onChanged:(v)=>setState(()=>search=v)),
      const SizedBox(height:12),
      ...list.map((p){final cat=firstMatch(categories,(c)=>c['id']==p['category_id']);return Card(child:ListTile(
        leading:ClipRRect(borderRadius:BorderRadius.circular(8),child:SizedBox(width:48,height:48,child:p['image_url']!=null?Image.network(p['image_url'],fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.image)):const Icon(Icons.image_outlined))),
        title:Text(p['name']??'Product',maxLines:1,overflow:TextOverflow.ellipsis),
        subtitle:Text('${money((p['price'] as num?)?.toDouble())} · ${p['unit']??''} · Stock ${p['stock_quantity']??0} · ${cat?['name']??'Uncategorised'}'),
        trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit'){edit(p);}else{toggle(p);}},itemBuilder:(_)=>[const PopupMenuItem(value:'edit',child:Text('Edit')),PopupMenuItem(value:'toggle',child:Text(p['is_active']==true?'Hide':'Show'))]),
      ));}),
      if(list.isEmpty)empty('No products found.'),
      const SizedBox(height:16),section('Categories','Enable or hide product categories'),
      ...categories.map((c)=>Card(child:SwitchListTile(value:c['is_active']==true,title:Text(c['name']??'Category'),onChanged:(_)=>toggleCategory(c)))),
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
    const SizedBox(height:8),DropdownButtonFormField<String>(initialValue:category,decoration:dec('Category'),items:widget.categories.map((c)=>DropdownMenuItem(value:c['id'].toString(),child:Text(c['name']??'Category'))).toList(),onChanged:(v)=>setState(()=>category=v)),
    const SizedBox(height:8),DropdownButtonFormField<String>(initialValue:home??'',decoration:dec('Homepage section'),items:[const DropdownMenuItem(value:'',child:Text('None')), ...widget.homes.map((h)=>DropdownMenuItem(value:h['name'].toString(),child:Text(h['name'].toString())))],onChanged:(v)=>setState(()=>home=v)),
    OutlinedButton.icon(onPressed:()async{final x=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:82,maxWidth:1600);if(x!=null)setState(()=>image=x);},icon:const Icon(Icons.image),label:Text(image?.name??'Choose product image')),
    if(widget.product?['image_url']!=null)TextButton(onPressed:()=>setState(()=>remove=true),child:const Text('Remove current image')),
    const SizedBox(height:10),FilledButton(onPressed:saving?null:save,child:Text(saving?'Saving…':'Save product')),
  ])));
}

class OrdersPage extends StatefulWidget{const OrdersPage({super.key});@override State<OrdersPage> createState()=>_OrdersPageState();}
class _OrdersPageState extends State<OrdersPage>{
  bool loading=true;String search='',filter='all';List<Map<String,dynamic>> orders=[];
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
    final todayDate = DateTime.parse(today);
    bool matchesDeliveryDate(Map<String,dynamic> order) {
      if (filter == 'all') return true;
      final raw = order['delivery_date']?.toString();
      if (raw == null || raw.length < 10) return false;
      final parsed = DateTime.tryParse(raw.substring(0, 10));
      if (parsed == null) return false;
      final deliveryDay = DateTime(parsed.year, parsed.month, parsed.day);
      switch (filter) {
        case 'today':
          return deliveryDay == todayDate;
        case 'tomorrow':
          return deliveryDay == todayDate.add(const Duration(days: 1));
        case 'dayAfterTomorrow':
          return deliveryDay == todayDate.add(const Duration(days: 2));
        case 'yesterday':
          return deliveryDay == todayDate.subtract(const Duration(days: 1));
        case 'last7Days':
          return !deliveryDay.isBefore(todayDate.subtract(const Duration(days: 6))) && !deliveryDay.isAfter(todayDate);
        case 'last30Days':
          return !deliveryDay.isBefore(todayDate.subtract(const Duration(days: 29))) && !deliveryDay.isAfter(todayDate);
        case 'thisMonth':
          return deliveryDay.year == todayDate.year && deliveryDay.month == todayDate.month;
        case 'lastMonth':
          final lastMonth = DateTime(todayDate.year, todayDate.month - 1);
          return deliveryDay.year == lastMonth.year && deliveryDay.month == lastMonth.month;
        default:
          return false;
      }
    }
    final list=orders.where((o)=>q.isNotEmpty
      ? o['order_number'].toString().contains(q)
      : matchesDeliveryDate(o)).toList();
    if(loading)return const Center(child:CircularProgressIndicator());
    return RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(16),children:[
      section('Customer orders','${orders.length} total · ${orders.where((o)=>!['delivered','cancelled'].contains(o['status'])).length} active'),
      DropdownButtonFormField<String>(initialValue:filter,decoration:dec('Delivery date'),items:const [
        DropdownMenuItem(value:'all',child:Text('All Orders')),
        DropdownMenuItem(value:'today',child:Text('Today')),
        DropdownMenuItem(value:'yesterday',child:Text('Yesterday')),
        DropdownMenuItem(value:'tomorrow',child:Text('Tomorrow')),
        DropdownMenuItem(value:'dayAfterTomorrow',child:Text('Day after tomorrow')),
        DropdownMenuItem(value:'last7Days',child:Text('Last 7 days')),
        DropdownMenuItem(value:'last30Days',child:Text('Last 30 days')),
        DropdownMenuItem(value:'thisMonth',child:Text('This month')),
        DropdownMenuItem(value:'lastMonth',child:Text('Last month')),
      ],onChanged:(v)=>setState(()=>filter=v??'all')),
      const SizedBox(height:8),TextField(decoration:dec('Search order number'),keyboardType:TextInputType.number,onChanged:(v)=>setState(()=>search=v)),
      const SizedBox(height:12),
      ...list.map((o){final status=o['status'].toString();final items=List<Map<String,dynamic>>.from(o['order_items']??[]);final address=addr(o);final lat=o['latitude'],lng=o['longitude'];final map=lat is num&&lng is num?'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng':'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';final phone=o['customer_phone']?.toString();return Card(child:Padding(padding:const EdgeInsets.all(13),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Expanded(child:Text('Order #${o['order_number']}',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16))),Chip(label:Text(labels[status]??status))]),
        Text(DateFormat('d MMM yyyy, h:mm a').format(DateTime.parse(o['created_at']).toLocal()),style:const TextStyle(fontSize:11,color:muted)),
        Text('Delivery: ${o['delivery_date']}',style:const TextStyle(color:green,fontSize:12)),
        const Divider(),Text('Customer: ${phone??'Phone unavailable'}'),
        if(phone!=null)TextButton.icon(onPressed:()=>open('tel:$phone'),icon:const Icon(Icons.call),label:const Text('Call customer')),
        Text('${o['address_label']??'Delivery address'} · $address',style:const TextStyle(fontSize:12)),
        TextButton.icon(onPressed:()=>open(map),icon:const Icon(Icons.map_outlined),label:const Text('Open in Maps')),
        ...items.map((i)=>Row(children:[Expanded(child:Text('${i['quantity']} × ${i['product_name']} ${i['product_unit']}',style:const TextStyle(fontSize:12))),Text(orderMoney(((i['unit_price_cents'] as num?)??0)*((i['quantity'] as num?)??0)))])),
        const Divider(),Row(children:[Expanded(child:Text(o['payment_status']=='paid'?'Paid':'Cash on delivery',style:const TextStyle(color:muted,fontSize:11))),Text(orderMoney(o['total_cents']),style:const TextStyle(fontWeight:FontWeight.w800))]),
        if(next.containsKey(status))SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>change(o),child:Text(status=='placed'?'Confirm order':status=='confirmed'?'Start preparing':status=='preparing'?'Mark out for delivery':'Mark delivered'))),
      ])));}),
      if(list.isEmpty)empty('No orders match this date or search.'),
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
  @override Widget build(BuildContext context){if(loading)return const Center(child:CircularProgressIndicator());final p=product;return RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(16),children:[
    section('Pack sizes & pricing','Each pack consumes stock from the same physical inventory'),
    DropdownButtonFormField<String>(initialValue:selected,decoration:dec('Select product'),items:products.map((p)=>DropdownMenuItem(value:p['product_id'].toString(),child:Text(p['name']??'Product'))).toList(),onChanged:choose),
    if(p!=null)...[
      const SizedBox(height:14),Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(editing==null?'Add pack size':'Edit pack size',style:const TextStyle(fontWeight:FontWeight.w800)),
        const SizedBox(height:8),TextField(controller:name,decoration:dec('Pack name')),const SizedBox(height:8),TextField(controller:label,decoration:dec('Unit label')),
        const SizedBox(height:8),Row(children:[Expanded(child:TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:dec('Price ₹'))),const SizedBox(width:8),Expanded(child:TextField(controller:mrp,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:dec('MRP ₹')))]),
        const SizedBox(height:8),TextField(controller:consumption,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:dec('Stock consumed per pack (${p['inventory_unit']??'unit'})')),
        const SizedBox(height:8),Row(children:[Expanded(child:FilledButton(onPressed:busy?null:savePack,child:Text(editing==null?'Add pack':'Save pack'))),if(editing!=null)TextButton(onPressed:()=>setState(reset),child:const Text('Cancel'))]),
      ]))),
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Shared physical stock',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:8),
        Row(children:[Expanded(child:TextField(controller:stock,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:dec('Quantity'))),const SizedBox(width:8),SizedBox(width:110,child:TextField(controller:unit,decoration:dec('Unit')))]),
        const SizedBox(height:8),SizedBox(width:double.infinity,child:FilledButton.tonal(onPressed:busy?null:saveStock,child:const Text('Update shared stock'))),
        Text('Sellable: ${p['stock_quantity']??0} default packs · Physical: ${p['inventory_quantity']??0} ${p['inventory_unit']??'unit'}',style:const TextStyle(fontSize:11,color:muted)),
      ]))),
      section('Available pack options','${packs.length} variants'),
      ...packs.map((v)=>Card(child:ListTile(title:Text(v['variant_name']??'Pack'),subtitle:Text('${v['unit_label']} · ${money((v['price'] as num?)?.toDouble())} · consumes ${v['inventory_quantity_per_pack']} ${p['inventory_unit']??'unit'}'),trailing:PopupMenuButton<String>(onSelected:(a){if(a=='edit'){edit(v);}else{toggle(v);}},itemBuilder:(_)=>[const PopupMenuItem(value:'edit',child:Text('Edit')),PopupMenuItem(value:'toggle',child:Text(v['is_active']==true?'Disable':'Enable'))])))),
    ],if(products.isEmpty)empty('Add products before configuring pack sizes.')]));
  }
}

class ShopPage extends StatefulWidget{const ShopPage({super.key});@override State<ShopPage> createState()=>_ShopPageState();}
class _ShopPageState extends State<ShopPage>{
  bool loading=true,saving=false,open=true,online=true;final message=TextEditingController(text:'We are not accepting new orders right now. Please try again later.');
  @override void initState(){super.initState();load();}
  @override void dispose(){message.dispose();super.dispose();}
  Future<void> load()async{setState(()=>loading=true);try{final r=await db.from('shop_settings').select('is_open,closed_message,accepting_online_orders').eq('id',1).single();open=r['is_open']==true;online=r['accepting_online_orders']==true;message.text=r['closed_message']?.toString()??message.text;}catch(e){if(mounted)toast(context,messageOf(e),error:true);}if(mounted)setState(()=>loading=false);}
  Future<void> save({bool? isOpen,bool? isOnline})async{setState(()=>saving=true);try{final data=<String,dynamic>{'updated_at':DateTime.now().toUtc().toIso8601String()};if(isOpen!=null)data['is_open']=isOpen;if(isOnline!=null)data['accepting_online_orders']=isOnline;if(isOpen==null&&isOnline==null)data['closed_message']=message.text.trim();await db.from('shop_settings').update(data).eq('id',1);if(isOpen!=null)open=isOpen;if(isOnline!=null)online=isOnline;if(mounted)toast(context,'Shop settings saved.');}catch(e){if(mounted)toast(context,messageOf(e),error:true);}if(mounted)setState(()=>saving=false);}
  @override Widget build(BuildContext context){if(loading)return const Center(child:CircularProgressIndicator());return RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(16),children:[
    section('Shop settings','Manage shop availability and checkout separately'),
    Card(child:SwitchListTile(value:open,onChanged:saving?null:(v)=>save(isOpen:v),activeThumbColor:green,title:Text(open?'Shop is open':'Shop is closed',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(open?'Customers can browse and place COD orders.':'Browsing remains available; checkout is paused.'),secondary:const Icon(Icons.storefront,color:green))),
    Card(child:SwitchListTile(value:online,onChanged:saving?null:(v)=>save(isOnline:v),activeThumbColor:green,title:Text(online?'Online orders enabled':'Online orders disabled',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('Controls the existing accepting_online_orders setting.'),secondary:const Icon(Icons.shopping_bag_outlined,color:green))),
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Checkout unavailable message',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:8),TextField(controller:message,maxLength:220,maxLines:4,decoration:dec('Customer-facing message')),SizedBox(width:double.infinity,child:FilledButton(onPressed:saving||message.text.trim().isEmpty?null:()=>save(),child:const Text('Save message')))]))),
    const Padding(padding:EdgeInsets.all(12),child:Text('Closing the shop affects new checkout only. Existing orders are not changed.',style:TextStyle(fontSize:12,color:muted))),
  ]));}
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
