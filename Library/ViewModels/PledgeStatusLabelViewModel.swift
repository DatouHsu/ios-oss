import Foundation
import KsApi
import Prelude
import ReactiveSwift

public protocol PledgeStatusLabelViewModelInputs {
  func configure(with project: Project)
  func viewDidLoad()
}

public protocol PledgeStatusLabelViewModelOutputs {
  var labelText: Signal<NSAttributedString, Never> { get }
}

public protocol PledgeStatusLabelViewModelType {
  var inputs: PledgeStatusLabelViewModelInputs { get }
  var outputs: PledgeStatusLabelViewModelOutputs { get }
}

public class PledgeStatusLabelViewModel: PledgeStatusLabelViewModelType,
  PledgeStatusLabelViewModelInputs, PledgeStatusLabelViewModelOutputs {
  public init() {
    let project = Signal.combineLatest(
      self.configureWithProjectStatusProperty.signal.skipNil(),
      self.viewDidLoadProperty.signal
    )
    .map(first)

    self.labelText = project.map(statusLabelText(with:)).skipNil()
  }

  private let configureWithProjectStatusProperty = MutableProperty<Project?>(nil)
  public func configure(with project: Project) {
    self.configureWithProjectStatusProperty.value = project
  }

  private let viewDidLoadProperty = MutableProperty(())
  public func viewDidLoad() {
    self.viewDidLoadProperty.value = ()
  }

  public let labelText: Signal<NSAttributedString, Never>

  public var inputs: PledgeStatusLabelViewModelInputs { return self }
  public var outputs: PledgeStatusLabelViewModelOutputs { return self }
}

// MARK: - Functions

private func statusLabelText(with project: Project) -> NSAttributedString? {
  let paragraphStyle = NSMutableParagraphStyle()
  paragraphStyle.alignment = .center

  let font = UIFont.ksr_subhead()
  let foregroundColor = UIColor.ksr_text_black

  let attributes = [
    NSAttributedString.Key.paragraphStyle: paragraphStyle,
    NSAttributedString.Key.font: font,
    NSAttributedString.Key.foregroundColor: foregroundColor
  ]

  if let stringFromProject = projectStatusLabelText(with: project) {
    return NSAttributedString(string: stringFromProject, attributes: attributes)
  }

  guard let backing = project.personalization.backing else { return nil }

  let string: String

  switch backing.status {
  case .canceled:
    string = localizedString(
      key: "You_canceled_your_pledge_for_this_project",
      defaultValue: "You canceled your pledge for this project."
    )
  case .collected:
    string = localizedString(
      key: "We_collected_your_pledge_for_this_project",
      defaultValue: "We collected your pledge for this project."
    )
  case .dropped:
    string = localizedString(
      key: "Your_pledge_was_dropped_because_of_payment_errors",
      defaultValue: "Your pledge was dropped because of payment errors."
    )
  case .errored:
    string = localizedString(
      key: "We_cant_process_your_pledge_Please_update_your_payment_method",
      defaultValue: "We can’t process your pledge. Please update your payment method."
    )
  case .pledged:
    return attributedConfirmationString(
      with: project,
      pledgeTotal: backing.amount
    )
  case .preauth:
    return nil
  }

  return NSAttributedString(string: string, attributes: attributes)
}

private func projectStatusLabelText(with project: Project) -> String? {
  let string: String

  switch project.state {
  case .canceled:
    string = localizedString(
      key: "The_creator_canceled_this_project_so_your_payment_method_was_never_charged",
      defaultValue: "The creator canceled this project, so your payment method was never charged."
    )
  case .failed:
    string = localizedString(
      key: "This_project_didnt_reach_its_funding_goal_so_your_payment_method_was_never_charged",
      defaultValue: "This project didn’t reach its funding goal, so your payment method was never charged."
    )
  case .live, .purged, .started, .submitted, .suspended, .successful:
    return nil
  }

  return string
}

private func attributedConfirmationString(with project: Project, pledgeTotal: Double) -> NSAttributedString {
  let date = Format.date(secondsInUTC: project.dates.deadline, template: "MMMM d, yyyy")
  let pledgeTotal = Format.currency(pledgeTotal, country: project.country)

  let font = UIFont.ksr_subhead()
  let foregroundColor = UIColor.ksr_text_black

  let paragraphStyle = NSMutableParagraphStyle()
  paragraphStyle.alignment = .center

  let attributes = [
    NSAttributedString.Key.paragraphStyle: paragraphStyle
  ]

  if project.stats.currentCurrency == project.stats.currency {
    return Strings.If_the_project_reaches_its_funding_goal_you_will_be_charged_on_project_deadline(
      project_deadline: date
    )
    .attributed(with: font, foregroundColor: foregroundColor, attributes: attributes, bolding: [date])
  }

  return Strings.If_the_project_reaches_its_funding_goal_you_will_be_charged_total_on_project_deadline(
    total: pledgeTotal,
    project_deadline: date
  )
  .attributed(
    with: font, foregroundColor: foregroundColor, attributes: attributes, bolding: [pledgeTotal, date]
  )
}
