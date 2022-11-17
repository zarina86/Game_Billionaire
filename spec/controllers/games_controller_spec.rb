require 'rails_helper'
require 'support/my_spec_helper'

RSpec.describe GamesController, type: :controller do
   # обычный пользователь
  let(:user) { FactoryBot.create(:user) }
   # админ
  let(:admin) { FactoryBot.create(:user, is_admin: true) }
   # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

  describe '#create' do
    context 'when the user is anonymous' do
      before do 
        post :create
        @game = assigns(:game)
      end

      it 'does not create a game' do 
        expect(@game).to be_nil
        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to be
      end
    end

    context 'when the user is logged in' do
      before(:each) { sign_in user }
            
      context 'current user does not have game in progress' do
        before do 
          generate_questions(15)
          post :create
          @game = assigns(:game)
        end
                    
        it 'creates game' do
          # проверяем состояние этой игры
          expect(@game.finished?).to be false
          expect(@game.user).to eq(user)
          expect(response).to redirect_to(game_path(@game))
          expect(flash[:notice]).to be
        end
      end

      context 'current user has game in progress' do 
        before do
          expect(game_w_questions.finished?).to be false
          expect { post :create }.to change(Game, :count).by(0)
          @game = assigns(:game)
        end

        it 'does not create a new game' do
          expect(@game).to be_nil
          expect(response).to redirect_to(game_path(game_w_questions))
          expect(flash[:alert]).to be
        end
      end
    end
  end
  
  describe '#show' do
    context 'when the user is anonymous' do
      before do 
        post :create
        @game = assigns(:game)
      end
      
      it 'does not show game' do
        expect(@game).to be_nil
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to be
      end
    end
    
    context 'when the user is logged in' do
      before(:each) { sign_in user }
      
      
      context 'attempt to see the game by game owner' do
        before do
          get :show, id: game_w_questions.id
          @game = assigns(:game)
        end
    
        it 'shows game' do
          expect(@game.finished?).to be false
          expect(@game.user).to eq(user)

          expect(response.status).to eq(200) 
          expect(response).to render_template('show') 
        end
      end

      context 'attempt to see the  game of the other person' do
        before do
          alien_game = FactoryBot.create(:game_with_questions)
          get :show, id: alien_game.id
        end

        it '#does not show game of the other person' do
          expect(response.status).not_to eq(200) 
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to be 
        end
      end
    end
  end 

  describe '#answer' do
    context 'when the user is anonymous' do
      before do
        put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
        @game = assigns(:game)
      end
      
      it 'attempt to answer is prohibited' do
        expect(@game).to be_nil
        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to be
      end
    end

    context 'when the user is logged in' do
      before(:each) { sign_in user }
        
      context 'attempt to answer question of his own game' do
        before do
          put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
          @game = assigns(:game)
        end

        it 'answers correct' do    
          expect(@game.finished?).to be false
          expect(@game.current_level).to be > 0
          expect(response).to redirect_to(game_path(@game))
          expect(flash.empty?).to be true 
        end
      end
    end
  end

  describe '#take_money' do 
    context 'when the user is anonymous' do
      before do
        game_w_questions.update_attribute(:current_level, 2)

        put :take_money, id: game_w_questions.id
        @game = assigns(:game)
      end

      it 'attempt to take_many is prohibited' do
        expect(@game).to be_nil
        expect(game_w_questions.finished?).to be false
        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to be
      end
    end
      
    context 'when the user is logged in' do
      before(:each) { sign_in user }

      context 'user finishes own game' do
        before do
          game_w_questions.update_attribute(:current_level, 2)

          put :take_money, id: game_w_questions.id
          @game = assigns(:game)
        end

        it 'takes money' do
          expect(@game.finished?).to be true
          expect(@game.prize).to eq(200)

          user.reload
          expect(user.balance).to eq(200)

          expect(response).to redirect_to(user_path(user))
          expect(flash[:warning]).to be
        end
      end
    end
  end
end
