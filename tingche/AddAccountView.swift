// Purpose: Sheet UI for adding a new account with validation.
// Author: Achord <achordchan@gmail.com>
import SwiftUI

struct AddAccountView: View {
    @Binding var isPresented: Bool
    @StateObject var accountManager: AccountManager
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Text("添加新账号")
                .font(.title2)
                .fontWeight(.medium)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 16) {
                // 账号输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text("账号")
                        .foregroundColor(.secondary)
                    TextField("请输入账号", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(height: 40)
                }
                
                // 密码输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text("密码")
                        .foregroundColor(.secondary)
                    HStack {
                        if isPasswordVisible {
                            TextField("请输入密码", text: $password)
                        } else {
                            SecureField("请输入密码", text: $password)
                        }
                        Button(action: {
                            isPasswordVisible.toggle()
                        }) {
                            Image(systemName: isPasswordVisible ? "eye.fill" : "eye.slash.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(height: 40)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // 底部按钮
            HStack(spacing: 16) {
                Button("取消") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .frame(width: 100)
                
                Button(action: {
                    Task {
                        await loginAndAddAccount()
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("添加")
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(width: 100)
                .disabled(username.isEmpty || password.isEmpty || isLoading)
            }
            .padding(.bottom)
        }
        .frame(width: 400, height: 300)
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("确定") {
                if alertTitle == "登录成功" {
                    accountManager.addAccount(username: username, password: password)
                    isPresented = false
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func validateForm() -> Bool {
        // 清除之前的错误信息
        errorMessage = nil
        
        // 验证手机号格式
        let phoneRegex = "^1[3-9]\\d{9}$"
        let phoneTest = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        
        if username.isEmpty {
            errorMessage = "请输入手机号"
            return false
        }
        
        if !phoneTest.evaluate(with: username) {
            errorMessage = "请输入正确的手机号格式"
            return false
        }
        
        if password.isEmpty {
            errorMessage = "请输入密码"
            return false
        }
        
        // 检查手机号是否已存在
        if accountManager.isPhoneNumberExists(username) {
            errorMessage = "该手机号已存在，请勿重复添加"
            return false
        }
        
        return true
    }
    
    private func loginAndAddAccount() async {
        guard validateForm() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let (isValid, token, uid) = try await APIService.shared.login(username: username, password: password)
            
            if isValid && token != nil {
                accountManager.addAccount(username: username, password: password, token: token, uid: uid)
                isPresented = false
            } else {
                alertTitle = "登录失败"
                alertMessage = errorMessage ?? "未知错误"
                showingAlert = true
            }
        } catch {
            alertTitle = "错误"
            alertMessage = error.localizedDescription
            showingAlert = true
        }
        
        isLoading = false
    }
}
