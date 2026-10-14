import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hospital_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nikController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _addressController = TextEditingController();
  String _gender = 'L';

  @override
  void dispose() {
    _nameController.dispose();
    _nikController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    _birthDateController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal lahir wajib diisi.')),
      );
      return;
    }
    final error = await context.read<HospitalProvider>().registerAccount(
          name: _nameController.text,
          nik: _nikController.text,
          phone: _phoneController.text,
          email: _emailController.text,
          password: _passwordController.text,
          passwordConfirmation: _passwordConfirmationController.text,
          birthDate: _birthDateController.text,
          gender: _gender,
          address: _addressController.text,
        );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat akun pasien')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Daftar akun',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Akun baru akan terhubung ke data pasien Anda.',
                    ),
                    const SizedBox(height: 24),
                    _field(
                      controller: _nameController,
                      label: 'Nama lengkap',
                      icon: Icons.person_outline,
                      validator: _required,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _nikController,
                      label: 'NIK',
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final nik = value?.trim() ?? '';
                        if (nik.length != 16) {
                          return 'NIK harus terdiri dari 16 digit.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _phoneController,
                      label: 'Nomor HP',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: _required,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _selectBirthDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        _birthDateController.text.isEmpty
                            ? 'Pilih tanggal lahir'
                            : 'Tanggal lahir: ${_birthDateController.text}',
                      ),
                    ),
                    if (_birthDateController.text.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Tanggal lahir wajib diisi.',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                        labelText: 'Jenis kelamin',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'L', child: Text('Laki-laki')),
                        DropdownMenuItem(value: 'P', child: Text('Perempuan')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _gender = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Alamat',
                        border: OutlineInputBorder(),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (!email.contains('@')) {
                          return 'Masukkan email yang valid.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _passwordController,
                      label: 'Password (minimal 8 karakter)',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      validator: (value) {
                        if ((value?.length ?? 0) < 8) {
                          return 'Password minimal 8 karakter.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _passwordConfirmationController,
                      label: 'Konfirmasi password',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      validator: (value) =>
                          value != _passwordController.text
                              ? 'Konfirmasi password tidak cocok.'
                              : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed:
                          context.watch<HospitalProvider>().isLoading
                              ? null
                              : _register,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Daftar dan masuk'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Data akun dan pasien disimpan di server rumah sakit '
                      'yang sama dengan portal web.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textCapitalization:
          keyboardType == TextInputType.emailAddress || keyboardType == TextInputType.number
              ? TextCapitalization.none
              : TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }

  String? _required(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Bagian ini wajib diisi.' : null;

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (date != null && mounted) {
      setState(() {
        _birthDateController.text =
            '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
      });
    }
  }
}
