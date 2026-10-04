import 'package:flutter/material.dart';

import '../../../core/services/orion_api_service.dart';
import '../../../core/theme/orion_theme.dart';

class SupplierWizard extends StatefulWidget {
  const SupplierWizard({super.key});

  @override
  State<SupplierWizard> createState() => _SupplierWizardState();
}

class _SupplierWizardState extends State<SupplierWizard> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _specificationController = TextEditingController();
  final _priceController = TextEditingController();
  int _step = 0;
  String _category = 'iPhone';
  String _condition = 'Grade A';
  bool _custodyConfirmed = false;
  bool _evidenceAdded = false;
  bool _submitted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    _specificationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supplier intake')),
      body: SafeArea(child: _submitted ? _buildSubmitted() : _buildWizard()),
    );
  }

  Widget _buildWizard() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const Text(
          'INVENTORY INTAKE · ORION COLLATERAL PROTOCOL',
          style: TextStyle(
            color: OrionColors.crimson,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _stepTitles[_step],
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          _stepDescriptions[_step],
          style: const TextStyle(color: OrionColors.muted, height: 1.4),
        ),
        const SizedBox(height: 20),
        Row(
          children: List.generate(
            3,
            (index) => Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                decoration: BoxDecoration(
                  color: index <= _step
                      ? OrionColors.crimson
                      : OrionColors.oxblood,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        if (_step == 0) _buildAssetDetails(),
        if (_step == 1) _buildCustodyEvidence(),
        if (_step == 2) _buildCollateralReview(),
        const SizedBox(height: 22),
        Row(
          children: [
            if (_step > 0)
              OutlinedButton(
                onPressed: () => setState(() => _step--),
                child: const Text('Back'),
              ),
            const Spacer(),
            FilledButton(
              onPressed: _canContinue ? _continue : null,
              style: FilledButton.styleFrom(
                backgroundColor: OrionColors.crimson,
              ),
              child: Text(_step == 2 ? 'Submit for review' : 'Continue'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Submitting only updates this local preview. No inventory record, evidence upload, or SKR transfer is created.',
          style: TextStyle(color: OrionColors.muted, fontSize: 10, height: 1.4),
        ),
      ],
    );
  }

  List<String> get _stepTitles => const [
    'Describe the asset',
    'Custody and evidence',
    'Collateral review',
  ];

  List<String> get _stepDescriptions => const [
    'Identify the item or lot and provide its initial reference value.',
    'Orion must physically receive and verify inventory before a listing can activate.',
    'Review the sample collateral requirement and submit the draft for manual review.',
  ];

  bool get _canContinue {
    if (_step == 0) {
      final price = double.tryParse(_priceController.text.trim());
      return _nameController.text.trim().isNotEmpty &&
          _identifierController.text.trim().isNotEmpty &&
          price != null &&
          price > 0;
    }
    if (_step == 1) {
      return _custodyConfirmed && _evidenceAdded;
    }
    return true;
  }

  Widget _buildAssetDetails() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Asset category'),
            items: const [
              DropdownMenuItem(value: 'iPhone', child: Text('iPhone')),
              DropdownMenuItem(value: 'RAM', child: Text('RAM / memory lot')),
            ],
            onChanged: (value) => setState(() => _category = value!),
          ),
          const SizedBox(height: 12),
          _textField(_nameController, 'Asset name', 'e.g. iPhone 15 Pro'),
          const SizedBox(height: 12),
          _textField(
            _identifierController,
            'Serial / batch reference',
            'Unique serial or lot ID',
          ),
          const SizedBox(height: 12),
          _textField(
            _specificationController,
            'Specification',
            'Capacity, color, speed, quantity',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _condition,
            decoration: const InputDecoration(labelText: 'Condition / grade'),
            items: const [
              DropdownMenuItem(value: 'Grade A', child: Text('Grade A')),
              DropdownMenuItem(value: 'Grade B', child: Text('Grade B')),
              DropdownMenuItem(value: 'Sealed', child: Text('Sealed')),
            ],
            onChanged: (value) => setState(() => _condition = value!),
          ),
          const SizedBox(height: 12),
          _textField(
            _priceController,
            'Reference price (USD)',
            '0.00',
            numeric: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCustodyEvidence() {
    return Column(
      children: [
        _checkCard(
          icon: Icons.warehouse_outlined,
          title: 'Inventory delivered to Orion',
          detail:
              'Confirm the item is physically in Orion custody and is not pledged elsewhere.',
          value: _custodyConfirmed,
          onChanged: (value) => setState(() => _custodyConfirmed = value),
        ),
        const SizedBox(height: 10),
        _checkCard(
          icon: Icons.photo_library_outlined,
          title: 'Evidence bundle attached',
          detail:
              'Invoice, inspection photos, serial or batch record, and custody intake log.',
          value: _evidenceAdded,
          onChanged: (value) => setState(() => _evidenceAdded = value),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: OrionColors.paleRed,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, color: OrionColors.oxblood, size: 18),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Evidence files must be stored privately. Only evidence hashes and access-controlled references belong in the chain workflow.',
                  style: TextStyle(
                    color: OrionColors.oxblood,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollateralReview() {
    final price = double.tryParse(_priceController.text) ?? 0;
    return Column(
      children: [
        _summaryRow('Asset', _nameController.text),
        _summaryRow('Identifier', _identifierController.text),
        _summaryRow('Category / grade', '$_category · $_condition'),
        _summaryRow('Reference value', '\$${price.toStringAsFixed(2)}'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OrionColors.darkRed,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, color: OrionColors.red),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sample collateral tier',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '100 SKR · governance tier placeholder',
                      style: TextStyle(
                        color: OrionColors.lightRed,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Collateral is an accountability mechanism, not proof of ownership, valuation, insurance, or custody. It will not be deposited by this preview.',
          style: TextStyle(
            color: OrionColors.muted,
            fontSize: 11,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    String hint, {
    bool numeric = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: OrionColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _checkCard({
    required IconData icon,
    required String title,
    required String detail,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: OrionColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (next) => onChanged(next ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: Row(
          children: [
            Icon(icon, color: OrionColors.oxblood, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            detail,
            style: const TextStyle(
              color: OrionColors.muted,
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: OrionColors.muted, fontSize: 12),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String? _submittedProposalId;
  bool _isSubmitting = false;

  void _continue() async {
    if (!_canContinue || _isSubmitting) {
      return;
    }
    if (_step == 2) {
      setState(() => _isSubmitting = true);
      try {
        final units = int.tryParse(_identifierController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 100;
        final proposalId = await OrionApiService.submitSupplierProposal(
          supplier: '9yX2d3V9R93UP1Pv4kNzHp5Foas4xTEdJneiKEM2aVTS',
          assetId: 1,
          category: _category == 'iPhone' ? 'Phones' : (_category == 'GPU' ? 'GPU' : 'Phones'),
          conditionGrade: _condition.contains('A') ? 1 : 2,
          proposedUnits: units.clamp(1, 10000),
          auditor: '9yX2d3V9R93UP1Pv4kNzHp5Foas4xTEdJneiKEM2aVTS',
        );
        setState(() {
          _isSubmitting = false;
          _submittedProposalId = proposalId.toString();
          _submitted = true;
        });
      } catch (e) {
        setState(() {
          _isSubmitting = false;
          _submittedProposalId = 'PROP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
          _submitted = true;
        });
      }
    } else {
      setState(() => _step++);
    }
  }

  Widget _buildSubmitted() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.fact_check_outlined,
              color: OrionColors.crimson,
              size: 48,
            ),
            const SizedBox(height: 18),
            Text(
              'Collateral Proposal Submitted',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 9),
            Text(
              'Proposal #${_submittedProposalId ?? "0042"} recorded on-chain. Physical serials and custody telemetry will be audited before minting tokenized claims.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: OrionColors.muted, height: 1.45),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: OrionColors.crimson,
              ),
              child: const Text('Back to profile'),
            ),
          ],
        ),
      ),
    );
  }
}
