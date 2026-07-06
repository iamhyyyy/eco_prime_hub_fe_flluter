import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'presentation/blocs/auth/auth_cubit.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/admin/admin_home_screen.dart';
import 'presentation/screens/manager/manager_home_screen.dart';
import 'presentation/screens/customer/customer_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(create: (_) => AuthCubit()..checkLoginStatus()),
      ],
      child: MaterialApp(
        title: 'Eco Prime Hub',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0D47A1),
            brightness: Brightness.light,
          ),
        ),
        home: const _SplashRouter(),
      ),
    );
  }
}

/// Màn hình trung gian: kiểm tra session rồi điều hướng
class _SplashRouter extends StatelessWidget {
  const _SplashRouter();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        // Đang kiểm tra session → hiện splash
        if (state is AuthLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D47A1),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_car_wash_rounded, size: 72, color: Colors.white),
                  SizedBox(height: 24),
                  Text(
                    'Eco Prime Hub',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 40),
                  CircularProgressIndicator(color: Colors.white70, strokeWidth: 2.5),
                ],
              ),
            ),
          );
        }

        // Đã đăng nhập → điều hướng theo role
        if (state is AuthSuccess) {
          final role = state.role.toLowerCase();
          if (role.contains('admin')) return const AdminHomeScreen();
          if (role.contains('manager')) return const ManagerHomeScreen();
          return const CustomerHomeScreen();
        }

        // Chưa đăng nhập → màn Login
        return const LoginScreen();
      },
    );
  }
}