import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hospital_models.dart';
import '../providers/hospital_provider.dart';
import '../services/hospital_api_client.dart';

class TeleconsultationsScreen extends StatelessWidget {
  const TeleconsultationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HospitalProvider>();
    final sessions = provider.teleconsultations;
    return Scaffold(
      appBar: AppBar(title: const Text('Telekonsultasi')),
      body: RefreshIndicator(
        onRefresh: provider.refreshPortal,
        child: sessions.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.chat_bubble_outline, size: 48),
                  SizedBox(height: 16),
                  Center(child: Text('Belum ada jadwal telekonsultasi.')),
                  SizedBox(height: 8),
                  Center(
                    child: Text('Buat pendaftaran dengan layanan telekonsultasi.'),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Pesan dikirim ke dokter pada jadwal konsultasi yang dipilih.',
                  ),
                  const SizedBox(height: 12),
                  ...sessions.map(
                    (session) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.medical_services_outlined),
                        ),
                        title: Text(session.appointment.patientName),
                        subtitle: Text(
                          '${session.appointment.doctor} · '
                          '${session.appointment.poly}\n'
                          '${session.appointment.date} · '
                          '${_statusLabel(session.appointment.status)}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TeleconsultationChatScreen(
                              appointment: session.appointment,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class TeleconsultationChatScreen extends StatefulWidget {
  const TeleconsultationChatScreen({required this.appointment, super.key});

  final Appointment appointment;

  @override
  State<TeleconsultationChatScreen> createState() =>
      _TeleconsultationChatScreenState();
}

class _TeleconsultationChatScreenState
    extends State<TeleconsultationChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<TeleconsultationMessage> _messages = [];
  Timer? _pollingTimer;
  bool _canSend = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refresh(showError: false),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appointment.doctor),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(widget.appointment.poly),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang pesan',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(onPressed: _refresh, child: const Text('Coba lagi')),
              ],
            ),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text('Belum ada pesan. Silakan mulai percakapan.'),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _MessageBubble(message: _messages[index]),
                  ),
          ),
          if (!_canSend)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Chat tidak aktif untuk akun ini atau konsultasi telah selesai.',
                textAlign: TextAlign.center,
              ),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 3000,
                        decoration: const InputDecoration(
                          hintText: 'Tulis pesan untuk dokter',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Kirim',
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _refresh({bool showError = true}) async {
    try {
      final provider = context.read<HospitalProvider>();
      final results = await Future.wait([
        provider.loadTeleconsultationMessages(widget.appointment.id),
        provider.canSendTeleconsultationMessage(widget.appointment.id),
      ]);
      if (!mounted) return;
      setState(() {
        _messages = results[0] as List<TeleconsultationMessage>;
        _canSend = results[1] as bool;
        _error = null;
      });
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    } on HospitalApiException catch (error) {
      if (mounted && showError) setState(() => _error = error.message);
    }
  }

  Future<void> _send() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _sending || !_canSend) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context
          .read<HospitalProvider>()
          .sendTeleconsultationMessage(widget.appointment.id, message);
      _messageController.clear();
      await _refresh();
    } on HospitalApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final TeleconsultationMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final time = message.sentAt == null
        ? ''
        : '${message.sentAt!.hour.toString().padLeft(2, '0')}:'
            '${message.sentAt!.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment:
          message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isMine
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            Text(message.message),
            if (time.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  time,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String status) => switch (status) {
      'PENDING' => 'Menunggu konfirmasi',
      'CONFIRMED' => 'Dikonfirmasi',
      'CHECKED_IN' => 'Berlangsung',
      'COMPLETED' => 'Selesai',
      _ => status,
    };
