# =============================================================================
# CloudFront Module - Origin Request Policies
# =============================================================================
# 
# このファイルはCloudFrontモジュールのオリジンリクエストポリシー定義を含みます。
# 「何をオリジンへ転送するか」を定義します。キャッシュキーとは別概念です。
# =============================================================================

# -----------------------------------------------------------------------------
# A. 管理画面/ログイン用：すべて転送（Cookie/Headers/QS）
# -----------------------------------------------------------------------------

resource "aws_cloudfront_origin_request_policy" "all_to_origin" {
  name    = "${var.project}-wp-all-to-origin"
  comment = "Forward all headers, cookies, and query strings to origin"

  cookies_config { 
    cookie_behavior = "all" 
  }
  headers_config { 
    header_behavior = "allViewer" 
  }
  query_strings_config { 
    query_string_behavior = "all" 
  }
}

# -----------------------------------------------------------------------------
# B. 静的ファイル用：最小限（QS のみ。Cookie/Headers は不要）
# -----------------------------------------------------------------------------

resource "aws_cloudfront_origin_request_policy" "static_minimal" {
  name    = "${var.project}-wp-static-minimal"
  comment = "Only forward query strings for static assets"

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

# -----------------------------------------------------------------------------
# C. 一般ページ用：Cookie もヘッダも全部転送（※WP がログイン判定やVaryを制御できる）
# -----------------------------------------------------------------------------

resource "aws_cloudfront_origin_request_policy" "dynamic_all" {
  name    = "${var.project}-wp-dynamic-all"
  comment = "Forward all for dynamic pages (origin decides cacheability)"

  cookies_config { 
    cookie_behavior = "all" 
  }
  headers_config { 
    header_behavior = "allViewer" 
  }
  query_strings_config { 
    query_string_behavior = "all" 
  }
}
