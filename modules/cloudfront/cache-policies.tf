# =============================================================================
# CloudFront Module - Cache Policies
# =============================================================================
# 
# このファイルはCloudFrontモジュールのキャッシュポリシー定義を含みます。
# WordPressのセキュリティとパフォーマンスを最適化するための設定です。
# =============================================================================

# -----------------------------------------------------------------------------
# 1. キャッシュ無効ポリシー（wp-admin / wp-login 用）
# -----------------------------------------------------------------------------

resource "aws_cloudfront_cache_policy" "caching_disabled" {
  name        = "${var.project}-wp-caching-disabled"
  comment     = "No caching for admin/login pages"
  default_ttl = 0
  min_ttl     = 0
  max_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = false
    enable_accept_encoding_brotli = false

    cookies_config {
      cookie_behavior = "none" # キャッシュ無効の場合はCookieも無視
    }
    headers_config {
      header_behavior = "none" # キャッシュポリシーではヘッダーは無視
    }
    query_strings_config {
      query_string_behavior = "none" # キャッシュ無効の場合はQueryStringも無視
    }
  }
}

# -----------------------------------------------------------------------------
# 2. 静的ファイル用の長期キャッシュ
# -----------------------------------------------------------------------------

resource "aws_cloudfront_cache_policy" "static_long" {
  name        = "${var.project}-wp-static-long-cache"
  comment     = "Long TTL for static assets"
  default_ttl = 2592000   # 30 days
  min_ttl     = 86400     # 1 day
  max_ttl     = 31536000  # 1 year

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    cookies_config {
      cookie_behavior = "none" # 静的ファイルはCookie無視
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "all" # バージョン付けに対応
    }
  }
}

# -----------------------------------------------------------------------------
# 3. 一般ページ用の短期キャッシュ（オリジンの Cache-Control を尊重）
# -----------------------------------------------------------------------------

resource "aws_cloudfront_cache_policy" "dynamic_short" {
  name        = "${var.project}-wp-dynamic-short-cache"
  comment     = "Short TTL for HTML pages"
  default_ttl = 60        # 1分
  min_ttl     = 0
  max_ttl     = 300       # 5分

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    # キャッシュキーは Cookie/ヘッダに影響されない（匿名ユーザーでヒットしやすい）
    cookies_config { 
      cookie_behavior = "none" 
    }
    headers_config { 
      header_behavior = "none" 
    }
    query_strings_config { 
      query_string_behavior = "all" 
    }
  }
}
