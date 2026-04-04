class GroupsController < ApplicationController
  before_action :authenticate_user!
  layout 'dashboard'
  before_action :set_group, only: [:show, :join, :leave, :infinite_feed]

  def index
    @tab = params[:tab].presence_in(%w[leaders groups]) || 'leaders'

    @my_leaders = load_my_leaders
    @my_groups = current_user.joined_groups.includes(:leader, :group_memberships).order('groups.name ASC').page(params[:page]).per(8)

    @suggested_groups = load_suggested_groups if @tab == 'groups'

    @top_leaders = User.joins(:led_groups)
                       .select('users.*, COUNT(groups.id) AS led_groups_count')
                       .group('users.id')
                       .order(Arel.sql('led_groups_count DESC'))
                       .limit(5)
                       .includes(:followers)

    @top_facts = Claim.published_facts
                      .left_joins(:likes)
                      .group('claims.id')
                      .order(Arel.sql('COUNT(likes.id) DESC'))
                      .limit(2)
                      .includes(:user)
  end

  def new
    @group = Group.new
    @selected_invitees = User.none
  end

  def create
    @group = Group.new(group_params.merge(leader: current_user))
    invitee_ids = selected_invitee_ids
    @selected_invitees = available_peers_scope.where(id: invitee_ids).order('users.full_name ASC NULLS LAST, users.email ASC')

    if @group.save
      @group.group_memberships.create!(user: current_user)
      if invitee_ids.any?
        invited_users = available_peers_scope.where(id: invitee_ids)
        invited_users.find_each do |invitee|
          invitee.notifications.create!(
            actor: current_user,
            key: 'group_invite',
            notifiable: @group,
            message: "#{current_user.full_name.presence || current_user.email} invited you to join #{@group.name}."
          )
        end
      end
      redirect_to groups_path(tab: 'groups'), notice: 'Group created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def invite_candidates
    query = params[:q].to_s.strip
    users = if query.length < 2
              User.none
            else
              available_peers_scope
                .where('users.full_name ILIKE :q OR users.email ILIKE :q', q: "%#{query}%")
                .order('users.full_name ASC NULLS LAST, users.email ASC')
                .limit(10)
            end

    render json: users.map { |user|
      {
        id: user.id,
        label: user.full_name.presence || user.email,
        subtitle: user.email
      }
    }
  end

  def show
    @is_member = @group.member?(current_user)
    @is_leader = @group.leader_id == current_user.id
    @group_members = group_members_for_show
    @top_facts = Claim.published_facts
                      .left_joins(:likes)
                      .group('claims.id')
                      .order(Arel.sql('COUNT(likes.id) DESC'))
                      .limit(2)
                      .includes(:user)
  end

  def infinite_feed
    member_ids = @group.group_memberships.pluck(:user_id)
    member_ids = (member_ids + [@group.leader_id]).uniq
    page = params[:page].to_i.positive? ? params[:page].to_i : 1
    per_page = page == 1 ? 30 : 20
    offset = (page - 1) * per_page

    facts = Claim.published_facts
                 .where(user_id: member_ids)
                 .includes(:user, :likes)
                 .order(created_at: :desc)
                 .offset(offset)
                 .limit(per_page)

    render json: {
      claims: facts.map { |fact|
        {
          html: render_to_string(
            partial: 'shared/feed_card',
            locals: { fact: fact, fact_card: true, group_feed: true },
            formats: [:html]
          ),
          id: fact.id,
          created_at: fact.created_at
        }
      },
      has_more: facts.size == per_page
    }
  end

  def join
    if @group.member?(current_user)
      redirect_to @group, notice: 'You are already in this group.'
    else
      @group.group_memberships.create!(user: current_user)
      redirect_to @group, notice: 'You joined the group.'
    end
  end

  def leave
    if @group.leader_id == current_user.id
      redirect_to @group, alert: 'Group leaders cannot leave their own group.'
      return
    end
    membership = @group.group_memberships.find_by(user: current_user)
    if membership
      membership.destroy
      redirect_to groups_path(tab: 'groups'), notice: 'You left the group.'
    else
      redirect_to @group
    end
  end

  private

  def set_group
    @group = Group.find(params[:id])
  end

  def group_params
    params.require(:group).permit(:name, :description)
  end

  def available_peers_scope
    User.where(id: current_user.peers.select(:id))
        .or(User.where(id: current_user.peer_users.select(:id)))
        .distinct
  end

  def selected_invitee_ids
    Array(params[:invitee_ids]).reject(&:blank?).map(&:to_i)
  end

  def load_my_leaders
    leader_ids = current_user.joined_groups.where.not(leader_id: current_user.id).distinct.pluck(:leader_id)
    scope = if leader_ids.empty?
              User.none
            else
              User.where(id: leader_ids).includes(:followers).order('users.full_name ASC NULLS LAST, users.email ASC')
            end
    scope.page(params[:page]).per(8)
  end

  def load_suggested_groups
    joined_ids = current_user.joined_groups.pluck(:id)
    scope = joined_ids.any? ? Group.where.not(id: joined_ids) : Group.all
    scope.includes(:leader, :group_memberships).limit(40).to_a.sort_by { |g| -g.group_memberships.size }.first(5)
  end

  # Sidebar list: top engaged non-leader members (by published fact count), max 3.
  def group_members_for_show
    leader_id = @group.leader_id
    ids = @group.group_memberships.pluck(:user_id).uniq.reject { |id| id == leader_id }
    return [] if ids.empty?

    fact_counts = Claim.published_facts
                       .where(user_id: ids)
                       .group(:user_id)
                       .count

    User.where(id: ids).includes(:avatar_attachment).to_a.sort_by do |u|
      [-fact_counts.fetch(u.id, 0), u.full_name.to_s.downcase, u.email.to_s.downcase]
    end.first(3)
  end
end
