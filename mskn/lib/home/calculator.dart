import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  // Controllers للـ TextFields
  final TextEditingController monthlyIncomeController =
      TextEditingController(text: '1000');
  final TextEditingController propertyPriceController =
      TextEditingController(text: '1000');
  final TextEditingController downPaymentController =
      TextEditingController(text: '0');
  final TextEditingController loanDurationController =
      TextEditingController(text: '1');
  final TextEditingController interestRateController =
      TextEditingController(text: '0');

  @override
  void dispose() {
    monthlyIncomeController.dispose();
    propertyPriceController.dispose();
    downPaymentController.dispose();
    loanDurationController.dispose();
    interestRateController.dispose();
    super.dispose();
  }

  // حساب المعدل بناءً على المدة
  double calculateInterestRate(double years) {
    if (years <= 5) return 3.5;
    if (years <= 10) return 3.8;
    if (years <= 15) return 4.2;
    if (years <= 20) return 4.5;
    if (years <= 25) return 4.8;
    return 5.0;
  }

  // حساب قيمة القرض (أصل القرض فقط)
  double get loanAmount {
    double price = double.tryParse(propertyPriceController.text) ?? 0;
    double downPayment = double.tryParse(downPaymentController.text) ?? 0;
    return price * (100 - downPayment) / 100;
  }

  // حساب إجمالي المبلغ المدفوع (أصل القرض + الفوائد)
  double get totalAmountPaid {
    double years = double.tryParse(loanDurationController.text) ?? 1;
    double months = years * 12;
    return monthlyPayment * months;
  }

  // حساب إجمالي الفوائد المدفوعة
  double get totalInterest {
    return totalAmountPaid - loanAmount;
  }

  // حساب الدفعة الأولى
  double get downPayment {
    double price = double.tryParse(propertyPriceController.text) ?? 0;
    double percentage = double.tryParse(downPaymentController.text) ?? 0;
    return price * percentage / 100;
  }

  // حساب الدفعة الشهرية
  double get monthlyPayment {
    double years = double.tryParse(loanDurationController.text) ?? 1;
    double interestRate = double.tryParse(interestRateController.text) ?? 0;
    double rate = interestRate / 100 / 12; // معدل شهري
    double months = years * 12;

    if (rate == 0 || loanAmount == 0) return loanAmount / months;

    return loanAmount *
        (rate * pow(1 + rate, months)) /
        (pow(1 + rate, months) - 1);
  }

  // حساب الحد الأقصى للقسط (55% من الدخل)
  double get maxMonthlyPayment {
    double income = double.tryParse(monthlyIncomeController.text) ?? 0;
    return income * 0.65;
  }

  // حساب نسبة القسط من الدخل
  double get paymentToIncomeRatio {
    double income = double.tryParse(monthlyIncomeController.text) ?? 1;
    if (income == 0) return 0;
    return (monthlyPayment / income) * 100;
  }

  // التحقق إذا كان القسط يتجاوز الحد المسموح
  bool get isPaymentExceeded {
    return monthlyPayment > maxMonthlyPayment;
  }

  String formatNumber(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FA),
      appBar: AppBar(
        title: const Text(
          'حاسبة القرض العقاري',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2196F3)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // الدخل الشهري
              _buildInputSection(
                title: 'الدخل الشهري',
                controller: monthlyIncomeController,
                unit: 'ر.س',
                min: 1000,
                max: 500000,
              ),
              const SizedBox(height: 15),

              // سعر العقار
              _buildInputSection(
                title: 'سعر العقار',
                controller: propertyPriceController,
                unit: 'ر.س',
                min: 1000,
                max: 100000000,
              ),
              const SizedBox(height: 15),

              // الدفعة الأولى
              _buildInputSection(
                title: 'الدفعة الأولى',
                controller: downPaymentController,
                unit: '%',
                min: 0,
                max: 100,
              ),
              const SizedBox(height: 15),

              // مدة سداد القرض
              _buildInputSection(
                title: 'مدة سداد القرض',
                controller: loanDurationController,
                unit: 'سنة',
                min: 1,
                max: 30,
              ),
              const SizedBox(height: 15),

              // معدل الفائدة
              _buildInputSection(
                title: 'معدل الفائدة',
                controller: interestRateController,
                unit: '%',
                min: 0,
                max: 15,
                isDecimal: true,
              ),
              const SizedBox(height: 20),

              // تحذير إذا تجاوز القسط 55% من الدخل
              if (isPaymentExceeded) ...[
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.red[700], size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'تحذير: القسط الشهري يتجاوز 65% من الدخل (${paymentToIncomeRatio.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // النتائج
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildResultCard(
                          title: 'قيمة القرض مع الفائدة',
                          value: 'ر.س ${formatNumber(totalAmountPaid)}',
                          color: const Color(0xFFE3F2FD),
                          icon: Icons.account_balance_wallet,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildResultCard(
                          title: 'إجمالي الفوائد',
                          value: 'ر.س ${formatNumber(totalInterest)}',
                          color: const Color.fromARGB(255, 178, 211, 255),
                          icon: Icons.money_off,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildResultCard(
                          title: 'الدفعة الشهرية',
                          value: 'ر.س ${formatNumber(monthlyPayment)}',
                          color: isPaymentExceeded
                              ? Colors.red[50]!
                              : const Color(0xFFBBDEFB),
                          icon: Icons.payment,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildResultCard(
                          title: 'نسبة من الدخل',
                          value: '${paymentToIncomeRatio.toStringAsFixed(1)}%',
                          color: isPaymentExceeded
                              ? Colors.red[100]!
                              : Colors.green[50]!,
                          icon: Icons.pie_chart,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildResultCard(
                    title: 'أصل القرض',
                    value: 'ر.س ${formatNumber(loanAmount)}',
                    color: const Color(0xFFC8E6C9),
                    icon: Icons.attach_money,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection({
    required String title,
    required TextEditingController controller,
    required String unit,
    required double min,
    required double max,
    bool isDecimal = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                unit,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0xFF2196F3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType:
                      TextInputType.numberWithOptions(decimal: isDecimal),
                  inputFormatters: isDecimal
                      ? [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ]
                      : [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFF2196F3),
            inactiveTrackColor: Colors.grey[300],
            thumbColor: const Color(0xFF1976D2),
            overlayColor: const Color(0xFF2196F3).withOpacity(0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: (double.tryParse(controller.text) ?? min).clamp(min, max),
            min: min,
            max: max,
            divisions:
                isDecimal ? ((max - min) * 10).toInt() : (max - min).toInt(),
            onChanged: (value) {
              setState(() {
                controller.text = isDecimal
                    ? value.toStringAsFixed(1)
                    : value.toStringAsFixed(0);
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFF1976D2),
            size: 24,
          ),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1E3A5F),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
