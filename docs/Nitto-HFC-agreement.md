# Business Case Proposal for Nitto: Wearable Stress Management for Special Child Parents

## 1. Executive Summary

### Objective

Improve the lives of parents with special needs children by using Nitto's wearable device to monitor stress levels and enable psychologist-led interventions.

In a 7-month proof-of-concept, Nitto and Hire for Care will deploy Nitto's wearable stress sensing device to continuously monitor parental stress levels managing special child and trigger psychologist-led interventions based on real-time stress data.

Together, Nitto and Hire for Care aim to co-develop a real-world-tested digital solution platform that can manage special-child parental stress through continuous wearable-based monitoring and psychologist-guided interventions, thereby delivering measurable gains across children's social-emotional, behavioural, cognitive, and health domains while establishing a scalable model for broader adoption.

### Value for Nitto

- **New Market Entry**: Proof of concept in India's special needs care sector.
- **Data-Driven Insights**: Real-world validation of stress management efficacy.
- **Scalable B2B Model**: Potential integration into HFC's subscription-based care plans.

## 2. Problem Statement

### Problem: Chronic Caregiver Stress and Its Impact

- **Massive scale of need**: Nearly *240 million* children worldwide have some form of disability. Parents of these children experience significantly higher stress and depression levels than other parents, facing relentless psychological pressure in their caregiving role.

- **Reduced support for child development**: Chronic stress drains parents' energy and focus, undermining their ability to effectively support their child's development. Research shows that high parenting stress can directly harm child outcomes – for instance, infants whose parents report extreme stress have 2× higher odds of developing mental health problems by age 3. In special needs contexts, this means crucial developmental interventions at home may be inconsistent or less effective when the caregiver is overwhelmed.

- **High burnout rates & family strain**: Prolonged stress often escalates into *parental burnout* – a state of intense exhaustion and self-doubt in one's parenting. Studies confirm parents of special needs children are far more prone to burnout, a syndrome with severe consequences (extreme cases even linked to suicidal ideation). This burnout not only harms the parent's mental health but also disrupts family well-being, leading to higher incidences of marital strain, social isolation, and overall caregiver fatigue.

- **Lack of real-time monitoring & proactive support**: Currently, there is no system in place to track caregiver stress in real time. Support tends to be reactive – interventions arrive only after a crisis or breakdown. Even healthcare providers often miss early warning signs of caregiver stress: one study found pediatricians underestimated or failed to detect high stress in one-third of cases, and overlooked related issues like caregiver isolation or financial strain 85% of the time. This gap leaves parents struggling without timely help, highlighting the need for a proactive solution that can catch rising stress before it reaches a breaking point.

### Nitto's Solution: Wearable-based stress tracking → AI-driven alerts → Psychologist-led care

- **24/7 wearable stress tracking**: Nitto proposes a comfortable, sensor-laden wearable that continuously monitors the parent's physiological stress indicators (such as heart rate variability or blood-flow changes). Data from the device is analyzed in real time by Nitto's proprietary algorithm, converting biosignals into an easy-to-understand stress score. This always-on monitoring provides an objective view of stress levels throughout the day, replacing guesswork with concrete data. *(Notably, this biofeedback-driven approach aligns with the APA's call for evidence-based practices in mental health care.)*

- **AI-driven early alerts**: Advanced AI analytics scrutinize the live data stream to detect stress spikes and worrisome patterns. When a caregiver's stress exceeds safe thresholds or shows a rapid rise, the system instantly issues an alert – sending notifications to the parent's smartphone and/or a connected care platform. These alerts come with personalized coping recommendations (e.g. breathing exercises, a reminder to take a break) or prompt the parent to initiate a telehealth check-in. By catching early signs of burnout, the AI ensures that small issues don't snowball: it enables timely, proactive interventions rather than waiting for the parent to hit a breaking point.

- **Psychologist-led proactive care**: A key differentiator of Nitto's solution is the integration of mental health professionals into the feedback loop. The real-time stress data and alert system are also connected to a dedicated psychologist or counselor dashboard. This allows licensed professionals to *accurately grasp in real time* how the parent is coping. Whenever a high-stress alert is triggered, a psychologist can promptly reach out – offering guidance, scheduling a counseling session, or adjusting the care plan as needed. Instead of traditional therapy that reacts after the fact, Nitto's model enables just-in-time support: counselors intervene at the moments of peak stress. This data-guided, human response not only prevents burnout by addressing issues *before* they escalate, but also provides parents with reassurance that someone is monitoring their well-being. In turn, caregivers stay more balanced and engaged, improving their capacity to support their child and bolstering overall family well-being.

Overall, Nitto's wearable-driven solution creates a closed-loop support system: it continuously monitors caregiver stress, uses AI to flag trouble early, and empowers psychologists to deliver timely, personalized care. By moving from reactive to proactive stress management, this approach aims to significantly reduce parental burnout and its ripple effects – helping special needs families thrive even under challenging conditions.

## 3. Proposed Solution: Nitto + HFC Partnership

### A. Technical Framework

- **API Integration**: Nitto's wearable data feeds into HFC's platform for real-time monitoring.
- **Stress Thresholds**: Interventions triggered after 60+ minutes of elevated stress.

### PoC Customer Journey

#### 1. On-boarding & Calibration (Days 1-10)

- Parent signs up and wears the device.
- System collects 10 days of baseline HRV to set a *personalized* Z-score threshold for "high stress." [Nitto wearable and control device].

#### 2. Continuous Monitoring (Day 11 onward)

- Wearable samples HR, Pulse pressure, HRV every few minutes, 24/7.
- Every check: Is stress ≥ personal threshold for >30 min?
  - **No** → Log the spike; keep monitoring.
  - **Yes (≥ 30 min at Level 4)**: Immediate Self-Help Trigger
    - Push notification appears.
    - App launches a 3-min paced-breathing guide (haptics + animation).
    - After exercise, user rates stress on a VAS and gets "Book counselling?" prompt (≤ 3 taps).

#### 3. User Decision Path

- **Books counselling** → Session scheduled; psychologist notes appear in dashboard.
- **Declines / ignores prompt** → Episode logged.

#### 4. No-Response Safeguard

- If user never opens the alert within 60 min:
  - Send WhatsApp / SMS follow-up.
  - Still no reply → case auto-flagged for care-team review.

#### 5. Night-time Logic

- Alerts suppressed while user is asleep.
- On first phone-unlock next morning, a summary notification invites booking if nocturnal stress occurred (compact view by default for privacy).

#### 6. 14-Day Stepped-Care Rule

- System counts episodes where user *declined* or stress persisted > 5 times / 14 days.
  - When threshold hit → Proactive psychologist outreach; case highlighted on clinician dashboard.

#### 7. Weekly Escalation Check

- Every 7 days: ≥ 7 sustained Level 4 events this week?
  - **Yes** → Escalate to 1-to-1 coaching / higher-intensity care.
  - **No** → Continue standard loop.

#### 8. Monthly Engagement Letter

- Auto-generated email summarises stress trends, interventions, sessions booked, and next-month tips.

#### 9. Data & UX Features

- HRV recovery and breathing-guide completion auto-logged.
- All events visualized on clinician dashboard for targeted follow-up.
- Privacy: lock-screen shows generic "Wellness alert"; details revealed only after unlock.
- User can schedule help or change preferences in ≤ 3 taps.

### Dashboard

Psychologists track trends & customize care plans.

### B. POC Study Design – 7 months, 75 parents

| Group | Sample Size (N) | Intervention | Purpose |
|-------|----------------|--------------|---------|
| Group A | 25 | Nitto Wearable + HFC Child Support | **Maximal Intervention**: Test the maximum impact on parental stress by combining technology *and* counseling support. This group examines whether using both the wearable (for biofeedback-driven stress management) and professional child-support counseling yields the greatest improvements in parent stress levels and child outcomes. |
| Group B | 25 | HFC intervention only | **Isolates the value of counselling without tech** |
| Group C | 25 | Wearable Control (No Active Intervention) | **Baseline Control**: Provides a baseline for comparison, measuring natural changes in stress and child outcomes without any active intervention – while controlling for any placebo or awareness effect of simply wearing a device. By having this group wear an inactive device, we ensure any improvements in Groups A or B are due to the interventions rather than the mere act of wearing a tracker (Hawthorne effect). |

### Statistical Power Analysis

| What this means for your PoC | Implication |
|------------------------------|-------------|
| Primary outcome (PSI-SF) now achieves ≈ 80% power without adding families, thanks to three time-points and baseline adjustment. High-frequency outcomes (meltdowns, sleep) are very well powered (≥ 95%). | You can credibly detect a moderate effect (d ≈ 0.6) on parent stress with the planned 30 × 3 sample. Even modest improvements will be statistically detectable; these endpoints can serve as sensitive secondary signals. |

### Statistical Analysis

| Outcome | Measurement Schedule | ρ (baseline ↔ follow-up) | Design / Analysis | Effective d after variance reduction* | Power with 30/arm |
|---------|---------------------|-------------------------|------------------|-----------------------------------|------------------|
| Parental stress (PSI-SF) | Baseline, 2.5 mo, 5 mo | ≈ 0.50 | Linear mixed model / ANCOVA | 0.60 × √(3 / [1+2ρ]) → 0.73 | ≈ 81% |
| Child behavioural meltdowns | Daily counts → weekly totals (≈ 20 points) | ≈ 0.30 | Mixed Poisson/negative binomial with random family intercept | 0.60 × √(20 / [1+19ρ]) → 1.04 | ≈ 98% |
| Sleep efficiency | Daily wearable data (≈ 140 nights) | ≈ 0.40 | Mixed model on nightly SE% with random family intercept | 0.60 × √(140 / [1+139ρ]) → 0.94 | ≈ 95% |

### C. System Architecture

```
Nitto Wearable → API → HFC Dashboard → Psychologist Alerts → Custom Interventions
```

## 4. Expected Outcomes & Value Proposition

### Key KPIs

#### 1. Clinical KPIs

##### i) Parental Stress Reduction
At least 50% of parents in Group A achieve PSI-SF reliable & clinically significant change as below target (Measure PSI-SF at baseline, and 5 months end point)

**Target**: ≥ *5-point raw drop and move below 85th percentile on the subscale.*

##### ii) Behavioural Regulation — frequency and severity of child meltdowns

| Metric | Tool | Collection Frequency |
|--------|------|---------------------|
| Weekly meltdown count & severity | In-app ABC log | Daily parent entry, auto summarized weekly |
| Therapist verification | 15-minute check-in call every week | Weekly |
| Analysis endpoint | Baseline vs. month 5 (and interim trend at month 2.5) | Statistical test: negative-binomial or Poisson mixed model |

**Target**: ≥30% reduction in mean weekly meltdowns for Group A vs. Group C with Cohen's d ≥ 0.5 (or equivalent rate ratio).

##### iii) Sleep Patterns
Stress-free bedtime routines and reduced family tension support better sleep.

| KPI (Parent Focused) | How to Measure with Wearable | Clinically Meaningful Target |
|---------------------|----------------------------|------------------------------|
| Total Sleep Time (TST) | • Device sums all sleep epochs each night.<br>• Report nightly minutes/hours and 14-night rolling average. | ≥ 7 hours per night on average (AASM/NSF adult guideline). |
| Sleep Efficiency (SE %) | • SE = (Total Sleep Time ÷ Time in Bed) × 100%.<br>• Device detects bed-in and bed out times. | ≥ 85% (≥ 90% ideal); < 85% indicates fragmented/inefficient sleep. |

#### 2. Business KPIs

**Caregiver Net Promoter Score (NPS)**: 0-10 likelihood-to-recommend survey at month 2.5 & 5.

**Go/No-Go suggestion**: Proceed if ≥ 50% of Group A meet KPI 1(i), ≥30% reduction in mean weekly meltdowns for Group A vs. Group C criteria and 30-day retention ≥ 50% with NPS > 20.

These KPIs satisfy three requirements:
1. **Standardized, peer-reviewed instruments** (PSI-SF) with published clinical cut-offs, ensuring comparability across studies.
2. **Objective statistical rules** (Reliable Change Index plus percentile thresholds) so results are not subjective.
3. **Business viability checks** (engagement + NPS) so a clinically positive but commercially unusable product is flagged early.

### Value Proposition for Nitto

✅ **Market Validation**: Proves wearable's effectiveness in mental health & caregiver support.  
✅ **B2B Expansion**: HFC can white-label/subscriptionize Nitto's tech post-POC.  
✅ **Data Asset**: Stress patterns from a high-stress demographic (valuable for R&D).  
✅ **VOC & Surveys**: Detailed survey reports will be done while doing POC wrt checking optimum pricing.

### Value Proposition for HFC & Parents

1. **Clinically meaningful reduction in parental stress levels**
2. **Improved child outcomes due to calmer, more engaged parents**
3. **Monetization**: Post-POC, integrate into HFC's parent wellness subscription plans

## 5. Project Plan

### Key Milestones

| Month / Phase | Milestone / Activity | Actionable | PIC |
|---------------|---------------------|------------|-----|
| Month 1 | Baseline stress tracking (Nitto data collection from Group C) & API integration | 1. Identify & finalize parent participants for baseline tracking.<br>2. Collaborate with Tech team for seamless API/data integration.<br>3. Marketing & stakeholder alignment. | **NAT** – Mathi, Nandhini, Seet, Sul (Device), Sayee (QC) Ohm Jenny (API integration) Kumar (stakeholder management.)<br>**HFC**- Ram |
| Month 2-6 | Interventions for Group A & B (intervention-led). | 1. Finalize parent cohorts for interventions.<br>2. Hire Clinical Team (Psychologists).<br>3. Roll out and monitor interventions | **NAT** – Mathi, Seet, Nandhini, Jenny, Ohm<br>**HFC**: Neha |
| Month 7 | Final report | Compile data, insights, and submit Proof of Concept report. | **NAT** – Kumar, Nandhini<br>**HFC**- Rajat |

### Timeline Summary

1. **Month 1**: Baseline stress tracking (Nitto data collection from Group C) & API integration.
2. **Month 2-6**: Interventions for Group A & B (intervention-led).
3. **Month 7**: Final data analysis and report.