//
//  ContentView.swift
//  card
//
//  Created by 김지환 on 8/9/24.
//

import SwiftUI
import Combine

struct Usage: Identifiable, Decodable {
    let id: Int
    let confirmType: String
    let date: String
    let time: String
    let fee: Int
    let place: String
}

class UsageViewModel: ObservableObject {
    @Published var usages:[Usage] = []
    @Published var isLoading = false
    @Published var errorMessage:String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    func fetchUsages(){
        guard let url = URL(string:"https://card-usages.vercel.app/api/usages-list") else {
            errorMessage = "잘못된 URL"
            return
        }
        isLoading = true
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type:[Usage].self,decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion:{ completion in
            switch completion{
            case .finished:
                break
            case .failure(let _error):
                self.errorMessage = "페칭 실패"
            }
            self.isLoading = false},receiveValue: {usages in
                self.usages = usages
            }).store(in: &cancellables)
    }
}

struct ContentView: View {
    @State private var fee  = "Loading"
    @State private var showDetails = false
    private var currentMonth: String{
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date())
    }
    var body: some View {
        NavigationView(content: {
            
            VStack {
                Text(currentMonth.uppercased()).font(.largeTitle).fontWeight(.bold).padding(2)
                Text("총 사용금액").font(.title2).foregroundColor(.gray)
                Text(fee)
                NavigationLink(destination: DetailsView()){
                    Text("상세내역보기").font(.headline).foregroundColor(.white).padding(6).background(Color.black).cornerRadius(16)
                }
            }
            .onAppear(perform: getCardUsagesByCurrentMonth)
        })
    }
    
    func getCardUsagesByCurrentMonth(){
        guard let url = URL(string:"https://card-usages.vercel.app/api/hello2") else {return}
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error : \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.fee = "Error\(error.localizedDescription)"
                }
                return
            }
            
            guard let data = data else {
                print("no data")
                DispatchQueue.main.sync {
                    self.fee = "No data"
                }
                return
            }
            
            do{
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any]{
                    print("response : \(json)")
                    
                    if let dataValue = json["data"] as? Int {
                        let formatter = NumberFormatter()
                        formatter.locale = Locale(identifier: "ko_KR")
                        formatter.numberStyle = .decimal
                        if let formattedNumber = formatter.string(from: NSNumber(value: dataValue)){
                            DispatchQueue.main.sync {
                                self.fee = "₩\(formattedNumber)"
                            }
                        }
                    }
                    
                    
                }
            }catch let err {
                print("json parsing error : \(err.localizedDescription)")
                DispatchQueue.main.sync {
                    self.fee = "\(err.localizedDescription)"
                }
            }
            
            
        }
        task.resume()
        
    }
}

struct DetailsView:View {
    @StateObject private var viewModel = UsageViewModel()
    private var currentMonthTitle:String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월"
        return formatter.string(from: Date())
    }
    
    var body: some View {
        VStack{
            Text("\(currentMonthTitle) 이용내역 상세")
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            }else{
                List(viewModel.usages) { usage in
                    HStack { // spacing: 0으로 설정하여 항목들 사이의 기본 여백을 제거
                                    VStack(alignment: .leading) {
                                        Text(usage.place)
                                            .font(.headline)
                                        HStack { // 항목들 사이의 간격 조정
                                            Text(usage.date)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Text(usage.time)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Text(usage.confirmType)
                                                .font(.system(size:10))
                                                .foregroundColor(.white)
                                                .padding(2)
                                                .background(usage.confirmType=="취소" ? Color.red : Color.black)
                                                .cornerRadius(8)
                                        }
                                    }
                                    Spacer() // 좌측 항목들 왼쪽 정렬을 보장합니다.
                                    Text("₩\(usage.fee)")
                                        .font(.headline)
                                        .strikethrough(usage.confirmType == "취소")
                    }.listRowSeparator(.hidden).navigationBarBackButtonHidden(false)
                }
                
                
            }
        }.onAppear {
            viewModel.fetchUsages()
        }
    }
}

#Preview {
    ContentView()
}
