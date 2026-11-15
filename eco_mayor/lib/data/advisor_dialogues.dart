import '../models/advisor_message.dart';

class AdvisorDialogues {
  static AdvisorMessage highAqiWarning(double aqi) {
    return AdvisorMessage(
      advisorId: 'priya',
      advisorName: 'Dr. Priya',
      title: 'Chief Ecologist',
      portraitAsset: 'assets/images/advisors/advisor_priya.png',
      message:
          'Mayor, our Air Quality Index has surged to ${aqi.toStringAsFixed(0)}! High particulate matter (PM2.5) from coal emissions causes severe respiratory distress among citizens.',
      evsConcept:
          'EVS Concept: Thermal power plants emit SO2, NOx, and fly ash. Transitioning to Solar Arrays reduces both carbon footprint and smog.',
    );
  }

  static AdvisorMessage dirtyWaterWarning(double water) {
    return AdvisorMessage(
      advisorId: 'arjun',
      advisorName: 'Chief Arjun',
      title: 'Municipal Engineer',
      portraitAsset: 'assets/images/advisors/advisor_arjun.png',
      message:
          'Water purity has dropped to ${water.toStringAsFixed(0)}%! Untreated effluent runoff is choking the local watershed.',
      evsConcept:
          'EVS Concept: Industrial wastewater requires primary sedimentation and secondary biological aeration to neutralize toxic biochemical oxygen demand (BOD).',
    );
  }

  static AdvisorMessage financialWarning(int funds) {
    return AdvisorMessage(
      advisorId: 'meera',
      advisorName: 'Minister Meera',
      title: 'Finance Director',
      portraitAsset: 'assets/images/advisors/advisor_meera.png',
      message:
          'Alert! City treasury reserves have dipped to \$$funds. We cannot afford green subsidies if our revenue drops to zero!',
      evsConcept:
          'EVS Concept: Sustainable development requires economic viability alongside ecological preservation—the "Triple Bottom Line" framework.',
    );
  }

  static AdvisorMessage greenPraise() {
    return AdvisorMessage(
      advisorId: 'rohan',
      advisorName: 'Citizen Rep Rohan',
      title: 'Community Leader',
      portraitAsset: 'assets/images/advisors/advisor_rohan.png',
      message:
          'The neighborhood feels alive! The new parks and green roofs are absorbing urban heat and citizens are outdoors enjoying the clean air.',
      evsConcept:
          'EVS Concept: Urban green belts serve as natural carbon sinks, dampen acoustic noise, and prevent topsoil erosion.',
    );
  }
}
