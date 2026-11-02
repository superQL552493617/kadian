import SwiftUI
import WebKit

// MARK: - 意见反馈：在 App 里打开私密问卷（腾讯问卷等），自动填好「用户 ID」

struct WebFeedbackView: View {
    let url: URL
    let fill: String
    @State private var loading = true
    var body: some View {
        ZStack {
            FormWebView(url: url, fill: fill, loading: $loading)
            if loading { ProgressView().controlSize(.large) }
        }
    }
}

struct FormWebView: UIViewRepresentable {
    let url: URL
    let fill: String
    @Binding var loading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// 问卷里标题含「用户 ID」的填空题自动填上（免费版问卷不能用链接传参，只能在页面里帮用户填）
    static func fillScript(_ text: String) -> String {
        let v = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        return """
        (function(){var V='\(v)',n=0;
        function setv(el){var p=el.tagName==='TEXTAREA'?HTMLTextAreaElement.prototype:HTMLInputElement.prototype;
          Object.getOwnPropertyDescriptor(p,'value').set.call(el,V);
          ['input','change','blur'].forEach(function(t){el.dispatchEvent(new Event(t,{bubbles:true}))})}
        function fill(){var all=document.querySelectorAll('body *');
          for(var i=0;i<all.length;i++){var e=all[i],t=(e.innerText||'').trim();
            if(t.length>60||!/(用户|用戶|User)\\s*ID/i.test(t))continue;
            if(e.querySelector&&[].some.call(e.children,function(c){return /(用户|用戶|User)\\s*ID/i.test(c.innerText||'')}))continue;
            var a=e;for(var k=0;k<8&&a;k++){var ins=a.querySelectorAll('input[type=text],input:not([type]),textarea');
              if(ins.length===1){if(!ins[0].value&&!ins[0].dataset.xmf){ins[0].dataset.xmf='1';setv(ins[0])}return}if(ins.length>1)break;a=a.parentElement}}}
        var iv=setInterval(function(){try{fill()}catch(e){}if(++n>120)clearInterval(iv)},500);})();
        """
    }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        if !fill.isEmpty {
            cfg.userContentController.addUserScript(WKUserScript(source: Self.fillScript(fill), injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: FormWebView
        init(_ p: FormWebView) { parent = p }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { DispatchQueue.main.async { self.parent.loading = false } }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { DispatchQueue.main.async { self.parent.loading = false } }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { DispatchQueue.main.async { self.parent.loading = false } }
    }
}
