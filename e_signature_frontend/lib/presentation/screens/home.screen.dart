import 'package:e_signature_frontend/presentation/screens/document_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import 'create_document_screen.dart';
import 'settings_screen.dart';
import '../../providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (!auth.isAuthCheckComplete) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isAuthenticated || auth.user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return const Scaffold();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'E-Signature',
          style: GoogleFonts.poppins(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.account_circle_outlined,
              color: AppColors.primaryText,
              size: 28,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          final token = auth.token;
          final userName = auth.user?['name'] ?? "Usuário";

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeHeader(userName),
                  const SizedBox(height: 32),
                  _buildQuickActions(context, token),
                  const SizedBox(height: 40),
                  _buildRecentActivitySection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, String? token) {
    final actions = [
      _buildActionCard(
        icon: Icons.add_to_drive_outlined,
        label: 'Criar Documento',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateDocumentScreen()),
          );
        },
      ),
      _buildActionCard(
        icon: Icons.folder_open_outlined,
        label: 'Meus Documentos',
        onTap: () {
          if (token != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DocumentsListScreen(token: token),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Token ainda não disponível. Aguarde.')),
            );
          }
        },
      ),
      _buildActionCard(
        icon: Icons.edit_outlined,
        label: 'Assinaturas Pendentes',
        onTap: () {},
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 1.1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) => actions[index],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.textFieldFill,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: AppColors.primaryButton),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(String userName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bem-vinda de volta,',
          style: GoogleFonts.poppins(
            fontSize: 22,
            color: AppColors.primaryText.withOpacity(0.7),
          ),
        ),
        Text(
          userName,
          style: GoogleFonts.poppins(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Atividade Recente',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 16),
        _buildRecentActivityItem(
          icon: Icons.check_circle_outline,
          title: 'Contrato de Serviço #CS1024',
          subtitle: 'Assinado por João Silva',
          statusColor: Colors.green,
        ),
        _buildRecentActivityItem(
          icon: Icons.pending_outlined,
          title: 'Proposta Comercial #PC2045',
          subtitle: 'Aguardando assinatura de Maria Souza',
          statusColor: Colors.orange,
        ),
        _buildRecentActivityItem(
          icon: Icons.cancel_outlined,
          title: 'Termo de Confidencialidade',
          subtitle: 'Recusado por Pedro Costa',
          statusColor: Colors.red,
        ),
      ],
    );
  }

  Widget _buildRecentActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.textFieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: statusColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.primaryText.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }
}
