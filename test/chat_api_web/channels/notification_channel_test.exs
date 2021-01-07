defmodule ChatApiWeb.NotificationChannelTest do
  use ChatApiWeb.ChannelCase
  import ChatApi.Factory

  alias ChatApi.Conversations

  setup do
    account = insert(:account)
    user = insert(:user, account: account)
    conversation = insert(:conversation, account: account)

    {:ok, _, socket} =
      ChatApiWeb.UserSocket
      |> socket("user_id", %{current_user: user})
      |> subscribe_and_join(ChatApiWeb.NotificationChannel, "notification:" <> account.id, %{
        "ids" => [conversation.id]
      })

    %{socket: socket, account: account, conversation: conversation, user: user}
  end

  test "ping replies with status ok", %{socket: socket} do
    ref = push(socket, "ping", %{"hello" => "there"})
    assert_reply ref, :ok, %{"hello" => "there"}
  end

  test "shout broadcasts to notification:lobby", %{
    socket: socket,
    account: account,
    conversation: conversation
  } do
    msg = %{
      body: "Hello world!",
      account_id: account.id,
      conversation_id: conversation.id
    }

    push(socket, "shout", msg)

    assert_push("shout", _msg)
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    broadcast_from!(socket, "broadcast", %{"some" => "data"})
    assert_push "broadcast", %{"some" => "data"}
  end

  describe "Updating first replied at" do
    test "conversation first replied at is updated", %{
      socket: socket,
      account: account,
      conversation: conversation
    } do
      inserted_at = DateTime.utc_now()

      msg = %{
        body: "Hello world!",
        account_id: account.id,
        conversation_id: conversation.id,
        inserted_at: inserted_at
      }

      ref = push(socket, "shout", msg)
      assert_reply(ref, :ok)
      conv = Conversations.get_conversation(conversation.id)

      assert conv.first_replied_at == DateTime.truncate(inserted_at, :second)
    end

    test "it only happens on first reply", %{
      socket: socket,
      account: account,
      conversation: conversation
    } do
      inserted_at = DateTime.utc_now()

      msg = %{
        body: "Hello world!",
        account_id: account.id,
        conversation_id: conversation.id
      }

      response = %{
        body: "goodbye world",
        account_id: account.id,
        conversation_id: conversation.id
      }

      ref = push(socket, "shout", msg)
      assert_reply(ref, :ok)

      Process.sleep(1000)

      ref1 = push(socket, "shout", response)
      assert_reply(ref1, :ok)

      conv = Conversations.get_conversation(conversation.id)

      assert conv.first_replied_at == DateTime.truncate(inserted_at, :second)
    end
  end

  test "conversation assignee is updated when first agent first replies", %{
    socket: socket,
    account: account,
    user: user,
    conversation: conversation
  } do
    msg = %{
      body: "Hello world!",
      account_id: account.id,
      conversation_id: conversation.id
    }

    ref = push(socket, "shout", msg)
    assert_reply(ref, :ok)
    conv = Conversations.get_conversation(conversation.id)

    assert conv.assignee_id == user.id
  end
end
