import 'dart:io';
import 'package:flutter/material.dart';

class ClothDetailScreen extends StatelessWidget {
  final Map<String, dynamic> cloth;

  const ClothDetailScreen({super.key, required this.cloth});

  @override
  Widget build(BuildContext context) {
    // cloth 맵에서 데이터를 추출합니다. 데이터가 null일 경우를 대비하여 기본값을 설정합니다.
    final String imagePath = cloth['clothingImg'] ?? '';
    final String name = cloth['name'] ?? '이름 없음';
    final String subCategory = cloth['subCategory'] ?? '분류 없음';
    final String articleType = cloth['articleType'] ?? '종류 없음';
    final String color = cloth['color'] ?? '색상 없음';
    final String memo = cloth['memo'] ?? '메모가 없어요. 클릭하여 수정할 수 있어요.';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // 뒤로가기 버튼 제거
        title: const Text('옷 상세정보', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(icon: const Icon(Icons.favorite_border, color: Colors.black), onPressed: () {}),
          IconButton(icon: const Icon(Icons.edit, color: Colors.black), onPressed: () {}),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.black), onPressed: () {}),
          IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 옷 이미지와 정보 섹션
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 왼쪽 옷 이미지
                Expanded(
                  flex: 2,
                  child: AspectRatio(
                    aspectRatio: 1 / 1.5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        image: imagePath.isNotEmpty
                            ? DecorationImage(
                          image: FileImage(File(imagePath)),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: imagePath.isEmpty
                          ? const Center(child: Icon(Icons.checkroom, size: 50, color: Colors.white))
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 오른쪽 옷 정보
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(Icons.label_outline, name),
                      _buildInfoRow(Icons.category_outlined, '$subCategory > $articleType'),
                      _buildInfoRow(Icons.color_lens_outlined, color),
                      _buildInfoRow(Icons.calendar_today_outlined, '24. 12. 17. 등록'), // 등록일은 예시 데이터입니다.
                      _buildInfoRow(Icons.history, '착용기록 4회', trailing: const Icon(Icons.arrow_forward_ios, size: 16)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(memo),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 새로운 룩 생성하기 버튼
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              label: const Text('이 옷으로 새로운 룩 생성하기', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Discovery 섹션
            const Text('Discovery', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: List.generate(3, (index) => _buildDiscoveryItem()),
              ),
            ),
            const SizedBox(height: 24),

            // Review 섹션
            const Text('Review', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                ...List.generate(4, (index) => const Icon(Icons.star, color: Colors.amber, size: 28)),
                const Icon(Icons.star_half, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                const Text('4.5', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('좋았음.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // 옷 정보 행을 만드는 위젯
  Widget _buildInfoRow(IconData icon, String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // Discovery 아이템 위젯
  Widget _buildDiscoveryItem() {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.checkroom, color: Colors.white, size: 40),
      ),
    );
  }
}