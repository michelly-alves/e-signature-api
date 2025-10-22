import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:developer';
import '../../data/repositories/document_repository.dart';
import '../../data/models/document_model.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';

class DocumentsListScreen extends StatefulWidget {
  final String token;
  const DocumentsListScreen({super.key, required this.token});

  @override
  State<DocumentsListScreen> createState() => _DocumentsListScreenState();
}

class _DocumentsListScreenState extends State<DocumentsListScreen> {
  late Future<List<Document>> _documentsFuture;
  bool _fetchInitiated = false;

  @override
  void initState() {
    super.initState();
    _documentsFuture = DocumentRepository().getDocuments(token: widget.token);
  }

  void _initiateDocumentsFetch(String token) {
    if (!_fetchInitiated) {
      _fetchInitiated = true;
      log('DocumentsListScreen: Iniciando busca de documentos com token: ${token.substring(0, 10)}...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _documentsFuture = DocumentRepository().getDocuments(token: token);
          });
        }
      });
    }
  }

  Widget _getStatusBadge(int statusId) {
    String text;
    Color color;
    switch (statusId) {
      case 1:
        text = 'Pendente';
        color = Colors.orange.shade700;
        break;
      case 2:
        text = 'Assinado';
        color = Colors.green.shade700;
        break;
      case 3:
        text = 'Recusado';
        color = Colors.red.shade700;
        break;
      default:
        text = 'Desconhecido';
        color = Colors.grey.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Meus Documentos',
            style: GoogleFonts.poppins(
                color: AppColors.primaryText, fontWeight: FontWeight.bold)),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          if (!auth.isAuthCheckComplete) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!auth.isAuthenticated || auth.token == null) {
            return const Center(
                child: Text('Erro de autenticação. Faça o login novamente.'));
          }

          _initiateDocumentsFetch(auth.token!);

          return FutureBuilder<List<Document>>(
            future: _documentsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child:
                        Text('Erro ao carregar documentos: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Nenhum documento encontrado.'));
              }

              final documents = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final doc = documents[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        log('Clicou no documento: ${doc.fileName}');
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              color: Theme.of(context).primaryColor,
                              size: 40,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc.fileName,
                                    style: GoogleFonts.poppins(
                                      color: AppColors.primaryText,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('dd/MM/yyyy \'às\' HH:mm')
                                        .format(doc.createdAt),
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            _getStatusBadge(doc.statusId),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
