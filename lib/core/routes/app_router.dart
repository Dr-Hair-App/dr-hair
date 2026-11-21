import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/views/signin_view.dart';
import '../../features/auth/presentation/views/complete_profile_view.dart';
import '../../features/appointments/presentation/clinic_appointment_view.dart';
import '../../features/auth/presentation/views/splash_view.dart';
import '../../features/hair_test/presentation/views/assessment_result_view.dart';
import '../../features/hair_test/presentation/views/hair_test_view.dart';
import '../../features/home/presentation/views/home_view.dart';
import '../../features/profile/presentation/views/profile_view.dart';
import '../../features/profile/presentation/views/settings_view.dart';
import '../../features/profile/presentation/views/update_profile_view.dart';
import '../../features/reviews/presentation/views/reviews_view.dart';
import '../../features/shell/presentation/views/main_shell_view.dart';
import '../../features/shop/data/models/product_model.dart';
import '../../features/shop/presentation/views/cart_view.dart';
import '../../features/shop/presentation/views/notifications_view.dart';
import '../../features/shop/presentation/views/checkout_view.dart';
import '../../features/shop/presentation/views/product_details_view.dart';
import '../../features/shop/presentation/views/products_view.dart';
import '../../features/static/domain/policy_models.dart';
import '../../features/static/presentation/views/about_view.dart';
import '../../features/static/presentation/views/no_internet_view.dart';
import '../../features/static/presentation/views/policy_page_view.dart';
import '../../features/treatment/presentation/views/treatment_details_view.dart';
import '../../features/videos/presentation/views/videos_view.dart';
import '../widgets/assessment_gate.dart';
import '../widgets/auth_gate.dart';
import '../../features/care/presentation/views/diet_plan_view.dart';
import '../../features/care/presentation/views/order_tracking_view.dart';
import '../../features/care/presentation/views/orders_list_view.dart';
import '../../features/care/presentation/views/progress_tracking_view.dart';
import '../../features/care/presentation/views/reminders_view.dart';
import '../../features/care/presentation/views/routine_tracker_view.dart';
import 'route_names.dart';

Widget _authenticatedRoute(GoRouterState state, Widget child) =>
    AuthRequiredRoute(routePath: state.uri.toString(), child: child);

class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.splash,
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashView(),
      ),
      // Persistent Bottom Navigation Shell via StatefulShellRoute (4 main tabs)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _authenticatedRoute(
            state,
            MainShellView(navigationShell: navigationShell),
          );
        },
        branches: [
          // 0. Home Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.mainShell,
                builder: (context, state) => HomeView(
                  onStartHairTest: () => context.push(RouteNames.hairTest),
                ),
              ),
            ],
          ),

          // 1. Reviews Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.reviews,
                builder: (context, state) => const ReviewsView(),
              ),
            ],
          ),

          // 2. Videos Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.videos,
                builder: (context, state) {
                  final initialVideoId =
                      state.uri.queryParameters['videoId'] ??
                      (state.extra is String ? state.extra as String : null);
                  return VideosView(initialVideoId: initialVideoId);
                },
              ),
            ],
          ),

          // 3. Profile Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.profile,
                builder: (context, state) => const ProfileView(),
              ),
            ],
          ),
        ],
      ),

      // Standalone full-screen routes that push over the shell (NO bottom nav, NO shell navbar)
      GoRoute(
        path: RouteNames.home,
        redirect: (context, state) => RouteNames.mainShell,
      ),
      GoRoute(
        path: RouteNames.hairTest,
        builder: (context, state) =>
            _authenticatedRoute(state, const HairTestView()),
      ),
      GoRoute(
        path: RouteNames.assessmentResult,
        builder: (context, state) {
          final refNo =
              state.uri.queryParameters['refNo'] ??
              (state.extra is String ? state.extra as String : null);
          return _authenticatedRoute(
            state,
            AssessmentRequiredRoute(
              child: AssessmentResultView(referenceNo: refNo),
            ),
          );
        },
      ),
      GoRoute(
        path: RouteNames.hairTestAssessment,
        builder: (context, state) {
          final refNo = state.pathParameters['refNo'];
          return _authenticatedRoute(
            state,
            AssessmentRequiredRoute(
              child: AssessmentResultView(referenceNo: refNo),
            ),
          );
        },
      ),
      GoRoute(
        path: RouteNames.universalAssessment,
        builder: (context, state) {
          final refNo = state.pathParameters['refNo'];
          return _authenticatedRoute(
            state,
            AssessmentRequiredRoute(
              child: AssessmentResultView(referenceNo: refNo),
            ),
          );
        },
      ),
      GoRoute(
        path: '/hair-test/assessment',
        redirect: (context, state) {
          final refNo = state.uri.queryParameters['refNo'];
          if (refNo != null && refNo.trim().isNotEmpty) {
            return RouteNames.hairTestAssessmentPath(refNo.trim());
          }
          return RouteNames.assessmentResult;
        },
      ),
      GoRoute(
        path: '/assessment',
        redirect: (context, state) {
          final refNo = state.uri.queryParameters['refNo'];
          if (refNo != null && refNo.trim().isNotEmpty) {
            return RouteNames.universalAssessmentPath(refNo.trim());
          }
          return RouteNames.assessmentResult;
        },
      ),
      GoRoute(
        path: RouteNames.updateProfile,
        builder: (context, state) =>
            _authenticatedRoute(state, const UpdateProfileView()),
      ),
      GoRoute(
        path: RouteNames.settings,
        builder: (context, state) =>
            _authenticatedRoute(state, const SettingsView()),
      ),
      GoRoute(
        path: RouteNames.treatmentDetails,
        builder: (context, state) => _authenticatedRoute(
          state,
          TreatmentDetailsView(
            initialReportId: state.uri.queryParameters['report_id'],
            initialReportsTab: state.uri.queryParameters['tab'] == 'reports',
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.cart,
        builder: (context, state) => _authenticatedRoute(
          state,
          CartView(initialItems: state.extra as List<Map<String, dynamic>>?),
        ),
      ),
      GoRoute(
        path: RouteNames.notifications,
        builder: (context, state) =>
            _authenticatedRoute(state, const NotificationsView()),
      ),
      GoRoute(
        path: RouteNames.productDetails,
        redirect: (context, state) =>
            state.extra is ProductItem ? null : RouteNames.products,
        pageBuilder: (context, state) {
          final product = state.extra as ProductItem;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: _authenticatedRoute(
              state,
              ProductDetailsView(initialProduct: product),
            ),
            transitionDuration: const Duration(milliseconds: 380),
            reverseTransitionDuration: const Duration(milliseconds: 320),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
          );
        },
      ),
      GoRoute(
        path: RouteNames.productById,
        pageBuilder: (context, state) {
          final id = state.pathParameters['productId'];
          final product = state.extra is ProductItem
              ? state.extra as ProductItem
              : ProductItem.findById(id);
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: _authenticatedRoute(
              state,
              ProductDetailsView(productId: id, initialProduct: product),
            ),
            transitionDuration: const Duration(milliseconds: 380),
            reverseTransitionDuration: const Duration(milliseconds: 320),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
          );
        },
      ),
      GoRoute(
        path: RouteNames.checkout,
        builder: (context, state) =>
            _authenticatedRoute(state, const CheckoutView()),
      ),
      GoRoute(
        path: RouteNames.products,
        builder: (context, state) =>
            _authenticatedRoute(state, const ProductsView()),
      ),
      GoRoute(
        path: RouteNames.signin,
        builder: (context, state) => const SigninView(),
      ),
      GoRoute(
        path: RouteNames.completeProfile,
        builder: (context, state) => _authenticatedRoute(
          state,
          CompleteProfileView(
            requireGender: state.uri.queryParameters['requireGender'] == 'true',
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.about,
        builder: (context, state) =>
            _authenticatedRoute(state, const AboutView()),
      ),
      GoRoute(
        path: RouteNames.routine,
        builder: (context, state) => AuthRequiredRoute(
          routePath: RouteNames.routine,
          child: AssessmentRequiredRoute(child: const RoutineTrackerView()),
        ),
      ),
      GoRoute(
        path: RouteNames.progress,
        builder: (context, state) => AuthRequiredRoute(
          routePath: RouteNames.progress,
          child: AssessmentRequiredRoute(
            child: ProgressTrackingView(
              autoOpenAddCheckIn: state.extra is bool && state.extra == true,
            ),
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.clinicAppointment,
        builder: (context, state) => const AuthRequiredRoute(
          routePath: RouteNames.clinicAppointment,
          child: ClinicAppointmentView(),
        ),
      ),
      GoRoute(
        path: RouteNames.dietPlan,
        builder: (context, state) => AuthRequiredRoute(
          routePath: RouteNames.dietPlan,
          child: AssessmentRequiredRoute(child: const DietPlanView()),
        ),
      ),
      GoRoute(
        path: RouteNames.reminders,
        builder: (context, state) => AuthRequiredRoute(
          routePath: RouteNames.reminders,
          child: AssessmentRequiredRoute(child: const RemindersView()),
        ),
      ),
      GoRoute(
        path: RouteNames.orders,
        builder: (context, state) => const AuthRequiredRoute(
          routePath: RouteNames.orders,
          child: OrdersListView(),
        ),
      ),
      GoRoute(
        path: RouteNames.orderTracking,
        builder: (context, state) => AuthRequiredRoute(
          routePath: RouteNames.orderTracking,
          child: OrderTrackingView(initialOrderId: state.extra as String?),
        ),
      ),
      GoRoute(
        path: RouteNames.policy,
        builder: (context, state) {
          final policyType =
              state.extra as PolicyType? ??
              PolicyType.fromSlug(state.uri.queryParameters['type']);
          return PolicyPageView(initialType: policyType);
        },
      ),
      GoRoute(
        path: RouteNames.privacyPolicy,
        builder: (context, state) =>
            const PolicyPageView(initialType: PolicyType.privacyPolicy),
      ),
      GoRoute(
        path: RouteNames.terms,
        builder: (context, state) =>
            const PolicyPageView(initialType: PolicyType.termsAndConditions),
      ),
      GoRoute(
        path: RouteNames.returnsRefunds,
        builder: (context, state) =>
            const PolicyPageView(initialType: PolicyType.returnsAndRefunds),
      ),
      GoRoute(
        path: RouteNames.cancellationPolicy,
        builder: (context, state) =>
            const PolicyPageView(initialType: PolicyType.cancellationPolicy),
      ),
      GoRoute(
        path: RouteNames.noInternet,
        builder: (context, state) => const NoInternetView(),
      ),
    ],
  );
}
