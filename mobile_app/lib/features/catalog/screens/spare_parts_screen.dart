import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/theme/theme.dart';
import '../models/category.dart';
import '../models/spare_part.dart';

class SparePartsScreen extends StatefulWidget {
  const SparePartsScreen({super.key});

  @override
  State<SparePartsScreen> createState() => _SparePartsScreenState();
}

class _SparePartsScreenState extends State<SparePartsScreen> {
  String _partsSearchQuery = '';
  CategoryModel? _selectedCategory;

  List<CategoryModel> _categories = [];
  List<SparePart> _spareParts = [];
  bool _partsLoading = true;
  int _currentPage = 1;
  final int _itemsPerPage = 6;

  @override
  void initState() {
    super.initState();
    _loadPartsData();
  }

  Future<void> _loadPartsData() async {
    setState(() => _partsLoading = true);
    try {
      final catRes = await ApiClient.get('/categories');
      final partsRes = await ApiClient.get('/spare-parts');
      
      final catsData = ApiClient.parseResponse(catRes) as List;
      final partsData = ApiClient.parseResponse(partsRes) as List;

      setState(() {
        _categories = catsData.map((e) => CategoryModel.fromJson(e)).toList();
        _spareParts = partsData.map((e) => SparePart.fromJson(e)).toList();
        _partsLoading = false;
      });
    } catch (_) {
      setState(() => _partsLoading = false);
    }
  }

  String _formatPrice(double price) {
    return '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VNĐ';
  }

  void _showPartDetails(SparePart part) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.canvas,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: AppColors.edge,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  if (part.imageUrl != null)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(part.imageUrl!, height: 200, fit: BoxFit.contain),
                      ),
                    )
                  else
                    Center(
                      child: Icon(Icons.build_circle_rounded, size: 80, color: AppColors.primaryHover),
                    ),
                  const SizedBox(height: 24),
                  Text(part.name, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 12),
                  Text(_formatPrice(part.price), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  const SizedBox(height: 24),
                  Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 8),
                  Text(part.description?.isNotEmpty == true ? part.description! : 'No description available for this spare part.', style: TextStyle(fontSize: 14, color: AppColors.inkMuted, height: 1.5)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _fieldShell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.edge),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.ink),
        title: Text('Spare Parts', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.2)),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_partsLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final filteredParts = _spareParts.where((part) {
      final matchesSearch = part.name.toLowerCase().contains(_partsSearchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == null || part.categoryId == _selectedCategory!.id;
      return matchesSearch && matchesCategory;
    }).toList();

    final totalPages = (filteredParts.length / _itemsPerPage).ceil();
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage < filteredParts.length)
        ? startIndex + _itemsPerPage
        : filteredParts.length;
    final paginatedParts = filteredParts.isEmpty ? <SparePart>[] : filteredParts.sublist(startIndex, endIndex);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: _fieldShell(
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 18, color: AppColors.inkMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: (val) {
                      setState(() {
                        _partsSearchQuery = val;
                        _currentPage = 1;
                      });
                    },
                    style: TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Search parts (e.g. Oil, Tire...)',
                      hintStyle: TextStyle(fontSize: 13, color: AppColors.inkMuted, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = null;
                    _currentPage = 1;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedCategory == null ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _selectedCategory == null ? AppColors.primary : AppColors.edge),
                  ),
                  child: Text('All', style: TextStyle(
                    fontSize: 12.5, 
                    fontWeight: _selectedCategory == null ? FontWeight.w700 : FontWeight.w600,
                    color: _selectedCategory == null ? Colors.white : AppColors.inkMuted
                  )),
                ),
              ),
              ..._categories.map((cat) {
                final isSelected = _selectedCategory?.id == cat.id;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat;
                      _currentPage = 1;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.edge),
                    ),
                    child: Text(cat.name, style: TextStyle(
                      fontSize: 12.5, 
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.inkMuted
                    )),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: filteredParts.isEmpty
              ? Center(child: Text('No parts found', style: TextStyle(color: AppColors.inkMuted)))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: paginatedParts.length,
                  itemBuilder: (context, index) {
                    final part = paginatedParts[index];
                    return GestureDetector(
                      onTap: () => _showPartDetails(part),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.edge),
                          boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Center(
                              child: part.imageUrl != null 
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(part.imageUrl!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                                    )
                                  : Icon(Icons.build_circle_rounded, size: 48, color: AppColors.primaryHover),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(part.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.2)),
                          const SizedBox(height: 4),
                          Text(_formatPrice(part.price), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
                        ],
                      ),
                    ));
                  },
                ),
        ),
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                  icon: Icon(Icons.chevron_left_rounded, color: _currentPage > 1 ? AppColors.ink : AppColors.inkMuted),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.edge),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text('Page $_currentPage of $totalPages', 
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.inkMuted, fontSize: 13)
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                  icon: Icon(Icons.chevron_right_rounded, color: _currentPage < totalPages ? AppColors.ink : AppColors.inkMuted),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.edge),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
