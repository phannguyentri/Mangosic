# YouTube Search

Tính năng tìm kiếm cho phép người dùng tìm kiếm video/nhạc trực tiếp từ YouTube mà không cần YouTube API key chính thức.

## Tính năng

### Các chức năng chính

| Chức năng | Mô tả |
|-----------|-------|
| **Search** | Tìm kiếm video YouTube theo từ khóa |
| **Autocomplete** | Gợi ý từ khóa khi người dùng đang gõ |
| **Recent Searches** | Lưu lại các tìm kiếm gần đây |
| **Retry Logic** | Tự động thử lại với API key khác nếu thất bại |

### Cách sử dụng

1. Mở **Search View** từ tab bar hoặc navigation
2. Tap vào **search bar** để bắt đầu tìm kiếm
3. Gõ từ khóa → autocomplete suggestions sẽ hiển thị
4. Tap vào suggestion hoặc nhấn Enter để search
5. Chọn kết quả để phát nhạc

## Kỹ thuật sử dụng

### InnerTube API (Không phải crawl HTML)

Tính năng search sử dụng **InnerTube API** - API nội bộ mà YouTube dùng cho web và mobile app của họ.

```
┌────────────────────────────────────────────────────────────────┐
│                     Kỹ thuật so sánh                            │
├──────────────────────┬─────────────┬───────────────────────────┤
│ Kỹ thuật             │ Được dùng?  │ Mô tả                      │
├──────────────────────┼─────────────┼───────────────────────────┤
│ InnerTube API        │ ✅ Có       │ API JSON nội bộ YouTube   │
│ HTML Crawling        │ ❌ Không    │ Parse HTML từ trang web   │
│ YouTube Data API v3  │ ❌ Không    │ API chính thức cần OAuth  │
│ Third-party packages │ ❌ Không    │ Như b5i/YouTubeKit        │
└──────────────────────┴─────────────┴───────────────────────────┘
```

### API Endpoints

| Endpoint | Method | Mục đích |
|----------|--------|----------|
| `https://www.youtube.com/youtubei/v1/search` | POST | Tìm kiếm video |
| `https://suggestqueries-clients6.youtube.com/complete/search` | GET | Autocomplete suggestions |

## Kiến trúc

```
┌──────────────────────────────────────────────────────────────────┐
│                         SearchView                                │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Search Bar                                                 │  │
│  │  → TextField với clear button                              │  │
│  └────────────────────────────────────────────────────────────┘  │
│                              │                                    │
│              ┌───────────────┴───────────────┐                   │
│              ▼                               ▼                    │
│  ┌────────────────────────┐    ┌────────────────────────────┐   │
│  │  Autocomplete List     │    │  Search Results List       │   │
│  │  (khi đang gõ)         │    │  (sau khi search)          │   │
│  └────────────────────────┘    └────────────────────────────┘   │
│                                              │                    │
│                                              ▼                    │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Recent Searches (khi search bar trống)                    │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                    YouTubeSearchService                           │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Configuration                                              │  │
│  │  ├── baseURL: https://www.youtube.com/youtubei/v1          │  │
│  │  ├── apiKeys: [3 rotating keys]                            │  │
│  │  └── clientContext: { WEB, version, "vi", "VN" }           │  │
│  ├────────────────────────────────────────────────────────────┤  │
│  │  Methods                                                    │  │
│  │  ├── search(query:limit:) → [SearchResult]                 │  │
│  │  ├── getAutocompleteSuggestions(query:) → [String]         │  │
│  │  └── rotateApiKey() (internal)                             │  │
│  ├────────────────────────────────────────────────────────────┤  │
│  │  Retry Logic                                                │  │
│  │  ├── maxRetries = 3                                        │  │
│  │  ├── Rotate API key on failure                             │  │
│  │  └── 0.5s delay between retries                            │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                        SearchResult                               │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Properties                                                 │  │
│  │  ├── id: String (YouTube video ID)                         │  │
│  │  ├── title: String                                         │  │
│  │  ├── author: String                                        │  │
│  │  ├── thumbnailURL: URL?                                    │  │
│  │  ├── duration: String?                                     │  │
│  │  ├── viewCount: String?                                    │  │
│  │  └── publishedTime: String?                                │  │
│  ├────────────────────────────────────────────────────────────┤  │
│  │  Methods                                                    │  │
│  │  └── toTrack() → Track (convert để phát nhạc)              │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

## Components

### 1. SearchResult (Model)

```swift
struct SearchResult: Identifiable, Equatable {
    let id: String           // YouTube video ID
    let title: String
    let author: String
    let thumbnailURL: URL?
    let duration: String?
    let viewCount: String?
    let publishedTime: String?
    
    func toTrack() -> Track { ... }
}

enum SearchState: Equatable {
    case idle
    case loading
    case loaded([SearchResult])
    case error(String)
}
```

**Vị trí**: `Mangosic/Models/SearchResult.swift`

### 2. YouTubeSearchService (Service)

```swift
@MainActor
class YouTubeSearchService: ObservableObject {
    static let shared = YouTubeSearchService()
    
    // Configuration
    private let baseURL = "https://www.youtube.com/youtubei/v1"
    private var apiKeys = [...]  // 3 rotating keys
    private let clientContext: [String: Any]  // WEB client info
    
    // Search Methods
    func search(query: String, limit: Int = 20) async throws -> [SearchResult]
    func getAutocompleteSuggestions(query: String) async throws -> [String]
    
    // Retry & Fallback
    private func rotateApiKey()
    var shouldConsiderFallback: Bool { ... }
}
```

**Vị trí**: `Mangosic/Services/YouTubeSearchService.swift`

### 3. SearchView (View)

Main search interface với các features:
- Search bar với placeholder và clear button
- Autocomplete suggestions list
- Search results với thumbnail, title, author, duration
- Recent searches management
- Loading và error states

**Vị trí**: `Mangosic/Views/SearchView.swift`

## Luồng hoạt động

### Search Flow

```
User gõ "lofi music"
        │
        ▼
Debounce 300ms (tránh spam API)
        │
        ▼
getAutocompleteSuggestions("lofi music")
        │
        ├── GET request đến suggestqueries API
        ├── Parse JSONP response
        └── Hiển thị suggestions dropdown
        │
        ▼
User tap Enter hoặc chọn suggestion
        │
        ▼
search(query: "lofi music", limit: 20)
        │
        ├── POST request đến InnerTube API
        │   └── Body: { context: { client: {...} }, query: "lofi music" }
        │
        ├── Parse JSON response
        │   └── Navigate: contents → twoColumnSearchResultsRenderer 
        │                 → primaryContents → sectionListRenderer
        │                 → contents → itemSectionRenderer → videoRenderer
        │
        └── Return [SearchResult]
                │
                ▼
        Hiển thị danh sách kết quả
                │
                ▼
        User tap vào kết quả
                │
                ├── searchResult.toTrack()
                └── PlayerViewModel.play(track)
```

### Retry Flow

```
search() called
        │
        ▼
performSearch() with apiKeys[0]
        │
        ├── Success → Return results, reset failure counter
        │
        └── Failure
                │
                ├── rotateApiKey() → Switch to apiKeys[1]
                ├── Wait 0.5 seconds
                └── Retry performSearch()
                        │
                        ├── Success → Return results
                        │
                        └── Failure (after 3 attempts)
                                │
                                ├── consecutiveFailures += 1
                                └── Throw error
```

### InnerTube API Request

```swift
// Request
POST https://www.youtube.com/youtubei/v1/search?key={API_KEY}
Content-Type: application/json
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36

{
    "context": {
        "client": {
            "clientName": "WEB",
            "clientVersion": "2.20240101.00.00",
            "hl": "vi",
            "gl": "VN"
        }
    },
    "query": "lofi music"
}
```

```javascript
// Response (simplified)
{
    "contents": {
        "twoColumnSearchResultsRenderer": {
            "primaryContents": {
                "sectionListRenderer": {
                    "contents": [{
                        "itemSectionRenderer": {
                            "contents": [{
                                "videoRenderer": {
                                    "videoId": "abc123",
                                    "title": { "runs": [{"text": "Lofi Hip Hop"}] },
                                    "ownerText": { "runs": [{"text": "ChillBeats"}] },
                                    "lengthText": { "simpleText": "3:45" },
                                    "viewCountText": { "simpleText": "1M views" },
                                    "thumbnail": {
                                        "thumbnails": [
                                            {"url": "https://i.ytimg.com/vi/abc123/hqdefault.jpg"}
                                        ]
                                    }
                                }
                            }]
                        }
                    }]
                }
            }
        }
    }
}
```

### Autocomplete API Request

```
GET https://suggestqueries-clients6.youtube.com/complete/search?client=youtube&q=lofi&ds=yt&hl=vi

// Response (JSONP format)
window.google.ac.h(["lofi",[["lofi music",0,[512]],["lofi hip hop",0,[512]],["lofi girl",0,[512]]],{...}])
```

## Ưu điểm & Nhược điểm

### Ưu điểm

| Ưu điểm | Mô tả |
|---------|-------|
| **Nhanh** | Nhận JSON trực tiếp, không cần parse HTML |
| **Ổn định hơn crawl** | Cấu trúc JSON ít thay đổi hơn HTML |
| **Không cần API key riêng** | Dùng key công khai embedded trong YouTube client |
| **Có retry logic** | Tự động xoay vòng API keys nếu một key fail |
| **Không dependencies** | Tự implement, không phụ thuộc package bên ngoài |

### Nhược điểm

| Nhược điểm | Mô tả |
|------------|-------|
| **API key có thể hết hạn** | YouTube thay đổi key định kỳ |
| **Không chính thức** | Có thể bị YouTube chặn nếu lạm dụng |
| **Rate limiting** | Có thể bị giới hạn nếu gọi quá nhiều |
| **Cấu trúc response phức tạp** | JSON response có nhiều nested levels |

## Error Handling

```swift
enum YouTubeSearchError: LocalizedError {
    case searchFailed(String)
    case noResults
    case fallbackRequired
    
    var errorDescription: String? { ... }
}
```

## Fallback Strategy

Nếu InnerTube API fail liên tục (>= 5 lần), có thể xem xét fallback sang `b5i/YouTubeKit` package:

```swift
// Kiểm tra nên fallback chưa
if YouTubeSearchService.shared.shouldConsiderFallback {
    // Implement b5i/YouTubeKit fallback
}
```

**Xem thêm**: Comment trong `YouTubeSearchService.swift` lines 320-364 để biết cách implement fallback.

## Testing

### Manual Testing Checklist

- [ ] Search bar hiển thị đúng với placeholder
- [ ] Gõ text → autocomplete suggestions hiển thị
- [ ] Tap suggestion → search được thực hiện
- [ ] Nhấn Enter → search được thực hiện
- [ ] Loading indicator hiển thị khi đang search
- [ ] Kết quả hiển thị với thumbnail, title, author, duration
- [ ] Tap vào kết quả → navigate đến player
- [ ] Error state hiển thị khi search fail
- [ ] Clear button xóa search text
- [ ] Recent searches được lưu và hiển thị

### Edge Cases

- [ ] Search với query rỗng → Không gọi API
- [ ] Search với ký tự đặc biệt (emoji, unicode)
- [ ] Network offline → Error handling
- [ ] API key expired → Rotate và retry
- [ ] Response parsing error → Graceful degradation

## Files liên quan

| File | Mô tả |
|------|-------|
| `Mangosic/Models/SearchResult.swift` | Model cho search result |
| `Mangosic/Services/YouTubeSearchService.swift` | Service xử lý InnerTube API |
| `Mangosic/Views/SearchView.swift` | UI cho search feature |
| `Mangosic/ViewModels/SearchViewModel.swift` | ViewModel (nếu có) |
