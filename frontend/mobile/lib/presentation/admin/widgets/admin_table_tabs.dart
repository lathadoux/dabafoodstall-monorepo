// path: frontend/mobile/lib/presentation/admin/widgets/admin_table_tabs.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/local_data_source.dart';
import 'admin_users_management_view.dart';

class AdminTableTabs extends ConsumerWidget {
  final String table;
  final VoidCallback onRefresh;

  const AdminTableTabs({super.key, required this.table, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: table == 'users' ? 3 : 2,
      child: Column(
        children: [
          TabBar(
            labelColor: AppTheme.primaryAmber,
            unselectedLabelColor: Colors.white60,
            indicatorColor: AppTheme.primaryAmber,
            tabs: [
              const Tab(text: "STRUCTURE"),
              const Tab(text: "DONNÉES"),
              if (table == 'users') const Tab(text: "RÉGLAGES RH"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildStructureView(ref),
                _buildDataView(ref),
                if (table == 'users') AdminUsersManagementView(onUserChanged: onRefresh),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStructureView(WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(localDataSourceProvider).getStructureTable(table),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final schema = snapshot.data!;
        return ListView.builder(
          itemCount: schema.length,
          itemBuilder: (context, i) => ListTile(
            dense: true,
            title: Text("${schema[i]['name']} [${schema[i]['type']}]", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: Text(schema[i]['notnull'] == 1 ? "NOT NULL" : "NULL", style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ),
        );
      },
    );
  }

  Widget _buildDataView(WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(localDataSourceProvider).getDonneesTable(table),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        if (list.isEmpty) return const Center(child: Text("Table vide", style: TextStyle(color: Colors.white30)));

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              columns: list.first.keys.map((k) => DataColumn(label: Text(k, style: const TextStyle(color: AppTheme.primaryAmber, fontWeight: FontWeight.bold)))).toList(),
              rows: list.map((row) => DataRow(
                cells: row.values.map((v) => DataCell(Text(v != null ? v.toString() : "NULL", style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)))).toList(),
              )).toList(),
            ),
          ),
        );
      },
    );
  }
}
