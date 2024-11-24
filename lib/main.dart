import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:kakao_flutter_sdk_navi/kakao_flutter_sdk_navi.dart';
import 'package:http/http.dart' as http;

// 상수 분리
class AppConstants {
  static const kakaoYellow = Color(0xFFFEE500);
  static const kakaoBrown = Color.fromRGBO(56, 35, 36, 1);

  static const buttonPadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 12,
  );
  static const defaultSpacing = 16.0;
  static const largeSpacing = 32.0;
  static const avatarRadius = 40.0;
}

// 공통으로 사용되는 스타일
class AppStyles {
  static final elevatedButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppConstants.kakaoYellow,
    foregroundColor: AppConstants.kakaoBrown,
    padding: AppConstants.buttonPadding,
  );

  static const searchFieldDecoration = InputDecoration(
    labelText: '목적지 입력',
    hintText: '장소명을 입력하세요',
    border: OutlineInputBorder(),
  );
}

// 에러 처리를 위한 유틸리티 클래스
class ErrorHandler {
  static void showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// API 응답을 위한 모델 클래스
class Place {
  final String name;
  final String address;
  final String roadAddress;
  final String category;
  final String x;
  final String y;
  final String phone;

  Place({
    required this.name,
    required this.address,
    required this.roadAddress,
    required this.category,
    required this.x,
    required this.y,
    required this.phone,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      name: json['place_name'] ?? '',
      address: json['address_name'] ?? '',
      roadAddress: json['road_address_name'] ?? '',
      category: json['category_name'] ?? '',
      x: json['x'] ?? '',
      y: json['y'] ?? '',
      phone: json['phone'] ?? '',
    );
  }

  Map<String, String> toMap() {
    return {
      'name': name,
      'address': address,
      'road_address': roadAddress,
      'category': category,
      'x': x,
      'y': y,
      'phone': phone,
    };
  }
}

// 최적화된 API 클래스
class KakaoSearchApi {
  // REST API 키
  static const String apiKey = "8938a9bd987f7a76e2955d29ed7c4c6ee";
  static KakaoSearchApi? _instance;
  http.Client? _client; // HTTP 클라이언트 재사용

  // private 생성자
  KakaoSearchApi._();

  // 싱글톤 인스턴스 getter
  static KakaoSearchApi get instance {
    _instance ??= KakaoSearchApi._();
    return _instance!;
  }

  Future<List<Place>> searchPlace(String query) async {
    if (query.trim().isEmpty) return const [];

    // 클라이언트가 없거나 닫혀있으면 새로 생성
    _client ??= http.Client();

    try {
      final response = await _client!.get(
        Uri.parse(
            'https://dapi.kakao.com/v2/local/search/keyword.json?query=$query'),
        headers: {'Authorization': 'KakaoAK $apiKey'},
      );
      debugPrint('응답 상태 코드 : ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('검색 결과 데이터 : $data');
        final List<Place> results = (data['documents'] as List)
            .map((place) => Place.fromJson(place))
            .toList();

        return results;
      }
      return const [];
    } catch (e) {
      debugPrint('장소 검색 실패: $e');
      return const [];
    }
  }

  void dispose() {
    _client?.close();
    _client = null;
  }
}

// 검색 결과 아이템 위젯
class SearchResultItem extends StatelessWidget {
  final Place place;
  final VoidCallback onNavigate;

  const SearchResultItem({
    super.key,
    required this.place,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(place.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.roadAddress.isNotEmpty
                ? place.roadAddress
                : place.address),
            if (place.category.isNotEmpty)
              Text(
                place.category,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: onNavigate,
          style: AppStyles.elevatedButtonStyle,
          child: const Text('길 안내'),
        ),
        isThreeLine: true,
      ),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Kakao SDK 초기화 - 네이티브 앱 키 설정
  KakaoSdk.init(
    nativeAppKey: 'e0d646fb8b53073637242d5b725b323514',
  );
  runApp(const KakaoLoginTest());
}

class KakaoLoginTest extends StatefulWidget {
  const KakaoLoginTest({super.key});

  @override
  State<KakaoLoginTest> createState() => _KakaoLoginTestState();
}

class _KakaoLoginTestState extends State<KakaoLoginTest> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kakao Login Test',
      // 앱의 전체적인 테마 설정
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          backgroundColor: AppConstants.kakaoYellow,
          foregroundColor: AppConstants.kakaoBrown,
          titleTextStyle: TextStyle(
            color: AppConstants.kakaoBrown,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const KakaoLogin(),
    );
  }
}

// 공통으로 사용되는 User 관련 Mixin
mixin UserStateMixin<T extends StatefulWidget> on State<T> {
  User? user;
  bool isLoading = true;

  // 상태 초기화 메서드 추가
  void resetState() {
    if (mounted) {
      setState(() {
        isLoading = true;
        user = null;
      });
    }
  }

  Future<void> loadUserData() async {
    try {
      User loadedUser = await UserApi.instance.me();
      if (mounted) {
        setState(() {
          user = loadedUser;
          isLoading = false;
        });
      }
      debugPrint('사용자 정보 요청 성공'
          '\n회원번호: ${loadedUser.id}'
          '\n닉네임: ${loadedUser.properties}');
    } catch (e) {
      if (mounted) {
        setState(() {
          user = null;
          isLoading = false;
        });
        handleError('사용자 정보를 불러오는데 실패했습니다: $e');
      }
    }
  }

  void handleError(String message) {
    if (!mounted) return;
    ErrorHandler.showError(context, message);
  }

  Widget buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  // 공통으로 사용되는 프로필 위젯
  Widget buildUserProfile() {
    return Column(
      children: [
        if (user?.kakaoAccount?.profile?.profileImageUrl != null)
          CircleAvatar(
            radius: AppConstants.avatarRadius,
            backgroundImage: NetworkImage(
              user!.kakaoAccount!.profile!.profileImageUrl!,
            ),
          ),
        const SizedBox(height: AppConstants.defaultSpacing),
        Text(
          '환영합니다, ${user?.kakaoAccount?.profile?.nickname ?? '사용자'}님!',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}

// 카카오 로그인 화면 위젯
class KakaoLogin extends StatefulWidget {
  const KakaoLogin({super.key});

  @override
  State<KakaoLogin> createState() => _KakaoLoginState();
}

class _KakaoLoginState extends State<KakaoLogin> with UserStateMixin {
  // 카카오톡 앱 설치 여부 상태
  bool _isKakaoTalkInstalled = false;

  @override
  void initState() {
    super.initState();
    _initKakaoTalkInstalled();
    loadUserData(); // 사용자 상태 로드
  }

  // 카카오톡 설치 여부 확인 함수
  Future<void> _initKakaoTalkInstalled() async {
    final installed = await isKakaoTalkInstalled();
    debugPrint('isKakaoTalkInstalled : $installed');
    debugPrint(await KakaoSdk.origin);
    if (mounted) {
      setState(() {
        _isKakaoTalkInstalled = installed;
      });
    }
  }

  // 로그인 처리 함수
  Future<void> _handleLogin() async {
    try {
      if (_isKakaoTalkInstalled) {
        debugPrint('카카오톡 설치됨');
        await _loginWithTalk(); // 카카오톡 설치되어 있으면 카카오톡으로 로그인
      } else {
        await _loginWithKakao(); // 미설치시 카카오 계정으로 로그인
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, '로그인 실패: $e');
      }
    }
  }

  Future<void> _loginWithKakao() async {
    try {
      OAuthToken token = await UserApi.instance.loginWithKakaoAccount();
      debugPrint('카카오계정으로 로그인 성공 ${token.accessToken}');
      await loadUserData(); // 로그인 후 사용자 정보 새로고침
      if (mounted) {
        _moveToLoginDone();
      }
    } catch (e) {
      debugPrint('카카오계정으로 로그인 실패 $e');
      rethrow;
    }
  }

  Future<void> _loginWithTalk() async {
    try {
      OAuthToken token = await UserApi.instance.loginWithKakaoTalk();
      debugPrint('카카오톡으로 로그인 성공 ${token.accessToken}');
      await loadUserData(); // 로그인 후 사용자 정보 새로고침
      if (mounted) {
        _moveToLoginDone();
      }
    } catch (e) {
      debugPrint('카카오톡으로 로그인 실패 $e');
      // 카카오톡에 연결된 카카오계정이 없는 경우, 카카오계정으로 로그인 시도
      await _loginWithKakao();
    }
  }

  Future<void> _handleLogout() async {
    try {
      await UserApi.instance.unlink();
      if (mounted) {
        setState(() {
          user = null;
        });
        ErrorHandler.showError(context, '로그아웃 성공');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, '로그아웃 실패: $e');
      }
    }
  }

  // 로그인 성공 후 화면 이동
  void _moveToLoginDone() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginDone()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(body: buildLoadingIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('카카오 로그인 테스트'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (user != null) ...[
              buildUserProfile(),
              const SizedBox(height: AppConstants.defaultSpacing),
              // 길 안내 버튼 목적지 입력(logindone) 위젯으로 넘어감
              ElevatedButton(
                onPressed: _moveToLoginDone,
                style: AppStyles.elevatedButtonStyle,
                child: const Text('길 안내 시작하기'),
              ),
              const SizedBox(height: AppConstants.defaultSpacing),
              // 로그아웃 버튼
              ElevatedButton(
                onPressed: _handleLogout,
                child: const Text('로그아웃'),
              ),
            ] else ...[
              // 로그인 버튼
              GestureDetector(
                onTap: _handleLogin,
                child: Image.asset(
                  'assets/kakao_login_large_narrow.png',
                  height: 90, // 카카오 로그인 버튼의 표준 높이
                  width: 366, // 적절한 너비 설정
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LoginDone extends StatefulWidget {
  const LoginDone({super.key});

  @override
  State<LoginDone> createState() => _LoginDoneState();
}

class _LoginDoneState extends State<LoginDone> with UserStateMixin {
  final TextEditingController _destinationController = TextEditingController();
  List<Place> _searchResults = const [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    KakaoSearchApi.instance.dispose();
    super.dispose();
  }

  // 장소 검색 함수
  Future<void> _searchPlace() async {
    // 검색시 키보드 숨기기
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    if (_destinationController.text.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await KakaoSearchApi.instance
          .searchPlace(_destinationController.text);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
        if (results.isEmpty) {
          handleError('검색 결과가 없습니다.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        handleError('검색 중 오류가 발생했습니다: $e');
      }
    }
  }

  // 선택한 장소로 네비게이션 실행
  Future<void> _navigateToPlace(Place place) async {
    try {
      if (await NaviApi.instance.isKakaoNaviInstalled()) {
        await NaviApi.instance.navigate(
          destination: Location(
            name: place.name,
            x: place.x,
            y: place.y,
          ),
          option: NaviOption(
            coordType: CoordType.wgs84,
          ),
        );
        // 내비게이션 실행 후 상태 갱신
        if (mounted) {
          loadUserData();
        }
      } else {
        await launchBrowserTab(Uri.parse(NaviApi.webNaviInstall));
        handleError('카카오내비 앱이 설치되어 있지 않습니다. 설치 페이지로 이동합니다.');
      }
    } catch (e) {
      handleError('네비게이션 실행 중 오류가 발생했습니다: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(body: buildLoadingIndicator());
    }
    return PopScope(
      canPop: false, // 기본 뒤로가기를 막습니다
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;

        // 뒤로가기 버튼 처리
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const KakaoLogin()),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('로그인 성공'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const KakaoLogin()),
              );
            },
          ),
        ),
        // Stack을 사용하여 배경 터치 영역과 컨텐츠를 분리
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                buildUserProfile(),
                const SizedBox(height: AppConstants.largeSpacing),
                // 검색 입력 필드
                TextField(
                  controller: _destinationController,
                  decoration: AppStyles.searchFieldDecoration.copyWith(
                    suffixIcon: IconButton(
                      icon: _isSearching
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : const Icon(Icons.search),
                      onPressed: _searchPlace,
                    ),
                  ),
                  onSubmitted: (_) => _searchPlace(), // 엔터키로 검색 가능
                  // 키보드의 검색 버튼을 검색 아이콘으로 변경
                  textInputAction: TextInputAction.search,
                ),
                const SizedBox(height: AppConstants.defaultSpacing),
                // 검색 결과 리스트
                Expanded(
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final place = _searchResults[index];
                      return SearchResultItem(
                        place: place,
                        onNavigate: () => _navigateToPlace(place),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
