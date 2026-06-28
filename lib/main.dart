import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'presentation/blocs/auth/auth_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // Load cấu hình IP
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(create: (context) => AuthCubit()),
      ],
      child: MaterialApp(
        title: 'Eco Prime Hub',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const LoginScreen(),
      ),
    );
  }
}

// Giao diện Màn hình đăng nhập đơn giản để test kết nối
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Eco Prime Hub - Đăng Nhập')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu')),
            const SizedBox(height: 20),
            BlocConsumer<AuthCubit, AuthState>(
              listener: (context, state) {
                if (state is AuthSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đăng nhập thành công!')));
                  // Điều hướng đến Dashboard tương ứng tùy vào role nhận được tại đây
                } else if (state is AuthFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
                }
              },
              builder: (context, state) {
                if (state is AuthLoading) return const CircularProgressIndicator();
                return ElevatedButton(
                  onPressed: () {
                    context.read<AuthCubit>().login(emailController.text, passwordController.text);
                  },
                  child: const Text('Đăng Nhập'),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}